<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<!DOCTYPE html>
<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>
<html>
<head>
    <title>WebRTC Chat</title>
    <script src="https://cdn.jsdelivr.net/npm/sockjs-client@1/dist/sockjs.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/stompjs@2.3.3/lib/stomp.min.js"></script>
    <style>
        button { margin: 5px; padding: 5px 10px; border-radius: 5px; }
        input, select { margin: 5px; }
        #groupMembers { margin-top: 10px; }
        #messages li.deleted .content { text-decoration: line-through; color: gray; }
        #messages li.edited em { font-size: 0.8em; color: blue; margin-left: 5px; }
        #messages li .status { font-size: 0.8em; margin-left: 10px; color: green; }
    </style>
</head>
<body>
<h2>WebRTC Chat</h2>

<!-- Group Selection and Creation -->
<div>
    <label>Group:</label>
    <select id="groupSelect">
        <option disabled selected>--Select Group--</option>
        <c:forEach items="${groups}" var="group">
            <option value="${group.id}">${group.name}</option>
        </c:forEach>
    </select>

    <input type="text" id="newGroupName" placeholder="New group name">
    <button onclick="createGroup()">Create Group</button>
    <button onclick="addMemberToGroup()">Add Member to Group</button>
    <button onclick="removeMemberFromGroup()">Remove Member from Group</button>
    <button onclick="deleteGroup()">Delete Group</button>
</div>

<!-- Display Group Members -->
<div id="groupMembers">
    <h4>Group Members:</h4>
    <ul id="memberList"></ul>
</div>

<!-- Chat Input and Typing -->
<div>
    <input type="text" id="message" placeholder="Type a message..." oninput="sendTyping()" disabled />
    <button onclick="sendMessage()" disabled id="sendBtn">Send</button>
    <p id="typingIndicator"></p>
</div>

<!-- Audio/Video Call -->
<div>
    <button onclick="startAudioCall()">Start Audio Call</button>
    <button onclick="startVideoCall()">Start Video Call</button>
    <button onclick="endCall()">End Call</button>
</div>

<!-- Online Users -->
<div>
    <h4>Online Users:</h4>
    <ul id="onlineUsers"></ul>
</div>

<!-- Video Section -->
<video id="localVideo" autoplay muted style="width: 300px; height: 200px;"></video>
<video id="remoteVideo" autoplay style="width: 300px; height: 200px;"></video>

<!-- Message List -->
<ul id="messages">
    <c:forEach items="${messages}" var="msg">
        <li id="${msg.id}" data-group="${msg.groupId}" class="${msg.deleted ? "deleted" : ""} ${msg.edited ? "edited" : ""}" style="display:none;">
            <strong>${msg.sender}</strong>: 
            <span class="content">${msg.deleted ? "[deleted]" : msg.content}</span>
            <c:if test="${msg.edited}"><em>[edited]</em></c:if>
            <span class="status">(${msg.status})</span>
        </li>
    </c:forEach>
</ul>

<script>
    let stompClient = null;
    let selectedGroup = "";
    const username = prompt("Enter your username:");
    const peerUsername = prompt("Enter peer username:");

    function connectWebSocket() {
        const socket = new SockJS('/ws');
        stompClient = Stomp.over(socket);
        stompClient.debug = null; // Disable debug logs for clarity

        stompClient.connect({}, function (frame) {
            console.log('Connected: ' + frame);

            // Subscribe to global messages topic
            stompClient.subscribe('/topic/messages', function (message) {
                const msg = JSON.parse(message.body);
                addOrUpdateMessage(msg);
            });

            // Subscribe to group messages for all groups user is member of
            // To optimize, we can subscribe only after group is selected (done below)
            // But let's subscribe to group messages topic to receive group messages:
            // For demo, subscribe to "/user/queue/groups" for group notifications
            stompClient.subscribe('/user/queue/groups', function (msg) {
                const group = JSON.parse(msg.body);
                console.log("Group notification received", group);
                // You can update groups dropdown or UI accordingly
                alert("Group update received: " + (group.name || group.groupId));
            });

            // Typing indicator subscription
            stompClient.subscribe('/topic/typing', function (msg) {
                const typing = JSON.parse(msg.body);
                const typingIndicator = document.getElementById("typingIndicator");
                if (typing.username !== username) {
                    typingIndicator.textContent = typing.isTyping ? typing.username + " is typing..." : "";
                }
            });

            // Status updates
            stompClient.subscribe('/topic/status', function (msg) {
                const statusUpdate = JSON.parse(msg.body);
                updateMessageStatusUI(statusUpdate);
            });

            // Online users
            stompClient.subscribe('/topic/online', function (msg) {
                const online = JSON.parse(msg.body);
                updateOnlineUsersUI(online);
            });

            // Signal messages (WebRTC)
            stompClient.subscribe('/user/queue/signal', function (msg) {
                const signal = JSON.parse(msg.body);
                handleSignal(signal);
            });
        }, function (error) {
            console.error('STOMP connection error:', error);
        });
        
    }

    // Add or update message on UI
    function addOrUpdateMessage(msg) {
        // Show only if message belongs to selected group
        if (msg.groupId !== selectedGroup) return;

        let li = document.getElementById(msg.id);
        if (!li) {
            li = document.createElement("li");
            li.id = msg.id;
            li.dataset.group = msg.groupId;
            document.getElementById("messages").appendChild(li);
        }
        li.className = (msg.deleted ? "deleted " : "") + (msg.edited ? "edited" : "");
        li.innerHTML = `<strong>${msg.sender}</strong>: <span class="content">${msg.deleted ? "[deleted]" : msg.content}</span>` +
                       (msg.edited ? "<em>[edited]</em>" : "") +
                       `<span class="status">(${msg.status})</span>`;
        li.style.display = "list-item";
    }

    function updateMessageStatusUI(statusUpdate) {
        let li = document.getElementById(statusUpdate.messageId);
        if (li) {
            const statusSpan = li.querySelector(".status");
            if (statusSpan) {
                statusSpan.textContent = "(" + statusUpdate.status + ")";
            }
        }
    }

    function updateOnlineUsersUI(online) {
        const ul = document.getElementById("onlineUsers");
        // Assume online contains {username: "...", online: true/false}
        let li = document.getElementById("user-" + online.username);
        if (!li && online.online) {
            li = document.createElement("li");
            li.id = "user-" + online.username;
            li.textContent = online.username;
            ul.appendChild(li);
        } else if (li && !online.online) {
            li.remove();
        }
    }

    function sendTyping() {
        if (!selectedGroup || !stompClient?.connected) return;
        const typingStatus = {
            username: username,
            isTyping: document.getElementById("message").value.length > 0
        };
        stompClient.send("/app/typing", {}, JSON.stringify(typingStatus));
    }

    function sendMessage() {
        if (!selectedGroup || !stompClient?.connected) return;
        const content = document.getElementById("message").value.trim();
        if (!content) return;
        const msg = {
            sender: username,
            content: content,
            groupId: selectedGroup,
            groupMessage: true
        };
        stompClient.send("/app/group/sendMessage", {}, JSON.stringify(msg));
        document.getElementById("message").value = "";
        sendTyping(); // clear typing
    }

    function createGroup() {
        const name = document.getElementById("newGroupName").value.trim();
        if (!name || !stompClient?.connected) return alert("Enter group name and ensure connected.");

        const groupData = {
            name: name,
            members: [username], // Creator is initial member
            createdBy: username
        };
        stompClient.send("/app/createGroup", {}, JSON.stringify(groupData));
        alert("Create group request sent.");
        document.getElementById("newGroupName").value = "";
    }

    function addMemberToGroup() {
        if (!selectedGroup) return alert("Select a group first.");
        const newUsername = prompt("Enter username to add:");
        if (!newUsername || !stompClient?.connected) return;
        const payload = { groupId: selectedGroup, username: newUsername };
        stompClient.send("/app/group/addMember", {}, JSON.stringify(payload));
        alert("Add member request sent.");
    }

    function removeMemberFromGroup() {
        if (!selectedGroup) return alert("Select a group first.");
        const usernameToRemove = prompt("Enter username to remove:");
        if (!usernameToRemove || !stompClient?.connected) return;
        const payload = { groupId: selectedGroup, username: usernameToRemove };
        stompClient.send("/app/group/removeMember", {}, JSON.stringify(payload));
        alert("Remove member request sent.");
    }

    function deleteGroup() {
        if (!selectedGroup) return alert("Select a group first.");
        if (!confirm("Are you sure you want to delete this group?")) return;
        const payload = { groupId: selectedGroup };
        stompClient.send("/app/group/delete", {}, JSON.stringify(payload));
        alert("Delete group request sent.");
    }

    document.getElementById("groupSelect").addEventListener("change", (e) => {
        selectedGroup = e.target.value;
        // Enable message input/send
        document.getElementById("message").disabled = false;
        document.getElementById("sendBtn").disabled = false;

        // Show messages only for this group
        const msgs = document.querySelectorAll("#messages li");
        msgs.forEach(li => {
            li.style.display = (li.dataset.group === selectedGroup) ? "list-item" : "none";
        });

        fetchGroupMembers(selectedGroup);
    });

    function fetchGroupMembers(groupId) {
        fetch(`/groups/${groupId}/members`)
            .then(res => res.json())
            .then(members => {
                const ul = document.getElementById("memberList");
                ul.innerHTML = "";
                members.forEach(member => {
                    const li = document.createElement("li");
                    li.textContent = member;
                    ul.appendChild(li);
                });
            })
            .catch(err => console.error("Failed to fetch group members", err));
    }

   


    // ---------------- WebRTC functions ----------------

    async function startCall(videoEnabled) {
        try {
            localStream = await navigator.mediaDevices.getUserMedia({
                video: videoEnabled,
                audio: true
            });
        } catch (e) {
            alert("Could not access camera/microphone: " + e.message);
            return;
        }

        document.getElementById("localVideo").srcObject = localStream;

        localConnection = new RTCPeerConnection();

        localStream.getTracks().forEach(track => {
            localConnection.addTrack(track, localStream);
        });

        localConnection.onicecandidate = event => {
            if (event.candidate) {
                // Send entire candidate object, not just candidate string
                sendSignal("ice", event.candidate);
            }
        };

        localConnection.ontrack = event => {
            document.getElementById("remoteVideo").srcObject = event.streams[0];
        };

        const offer = await localConnection.createOffer();
        await localConnection.setLocalDescription(offer);
        sendSignal("offer", offer.sdp, videoEnabled);

        // Setup call timeout 30 seconds
        callTimeout = setTimeout(() => {
            sendSignal("timeout");
            endCall();
            alert("Call timed out.");
        }, 30000);
    }

    function startAudioCall() {
        startCall(false);
    }

    function startVideoCall() {
        startCall(true);
    }

    function endCall() {
        sendSignal("end");
        if (localStream) {
            localStream.getTracks().forEach(track => track.stop());
            localStream = null;
        }
        if (localConnection) {
            localConnection.close();
            localConnection = null;
        }
        if (callTimeout) {
            clearTimeout(callTimeout);
            callTimeout = null;
        }
        document.getElementById("remoteVideo").srcObject = null;
        document.getElementById("localVideo").srcObject = null;
    }

    function sendSignal(type, sdpOrCandidate = null, videoEnabled = false) {
        if (!stompClient?.connected) return;

        const signal = {
            type: type,
            sender: username,
            receiver: peerUsername,
            videoEnabled: videoEnabled
        };

        if (type === "offer" || type === "answer") {
            signal.sdp = sdpOrCandidate;
        } else if (type === "ice") {
            // Send entire ICE candidate object
            signal.candidate = sdpOrCandidate;
        }

        stompClient.send("/app/signal", {}, JSON.stringify(signal));
    }

    async function handleSignal(signal) {
        if (!signal) return;

        switch (signal.type) {
            case "offer":
                localConnection = new RTCPeerConnection();

                localConnection.onicecandidate = event => {
                    if (event.candidate) {
                        sendSignal("ice", event.candidate);
                    }
                };

                localConnection.ontrack = event => {
                    document.getElementById("remoteVideo").srcObject = event.streams[0];
                };

                try {
                    localStream = await navigator.mediaDevices.getUserMedia({
                        video: signal.videoEnabled,
                        audio: true
                    });
                } catch (e) {
                    alert("Could not access camera/microphone: " + e.message);
                    return;
                }

                document.getElementById("localVideo").srcObject = localStream;

                localStream.getTracks().forEach(track => {
                    localConnection.addTrack(track, localStream);
                });

                await localConnection.setRemoteDescription(new RTCSessionDescription({
                    type: "offer",
                    sdp: signal.sdp
                }));

                const answer = await localConnection.createAnswer();
                await localConnection.setLocalDescription(answer);
                sendSignal("answer", answer.sdp, signal.videoEnabled);

                if (callTimeout) {
                    clearTimeout(callTimeout);
                    callTimeout = null;
                }
                break;

            case "answer":
                if (localConnection) {
                    await localConnection.setRemoteDescription(new RTCSessionDescription({
                        type: "answer",
                        sdp: signal.sdp
                    }));
                }
                if (callTimeout) {
                    clearTimeout(callTimeout);
                    callTimeout = null;
                }
                break;

            case "ice":
                if (signal.candidate && localConnection) {
                    try {
                        await localConnection.addIceCandidate(new RTCIceCandidate(signal.candidate));
                    } catch (e) {
                        console.warn("Error adding ICE candidate:", e);
                    }
                }
                break;

            case "end":
                endCall();
                alert("Call ended by peer.");
                break;

            case "timeout":
                endCall();
                alert("Call timed out.");
                break;
        }
    }

    connectWebSocket();
</script>
</body>
</html>
