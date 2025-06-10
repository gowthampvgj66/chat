<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<!DOCTYPE html>
<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>
<html>
<head>
    <title>WebRTC Chat</title>
    <script src="https://cdn.jsdelivr.net/npm/sockjs-client@1/dist/sockjs.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/stompjs@2.3.3/lib/stomp.min.js"></script>
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
        <li id="${msg.id}" data-group="${msg.groupId}">
            ${msg.sender}:
            <span class="content">${msg.deleted ? "[deleted]" : msg.content}</span>
            <c:if test="${msg.edited}"><em>[edited]</em></c:if>
            <span class="status">(${msg.status})</span>
        </li>
    </c:forEach>
</ul>

<script>
    let stompClient = null;
    let localConnection = null;
    let localStream = null;
    let callTimeout = null;
    const onlineUsers = {};
    const username = prompt("Enter your username:");
    const peerUsername = prompt("Enter peer username:");
    let selectedGroup = "";

    function connectWebSocket() {
        const socket = new SockJS('/ws');
        stompClient = Stomp.over(socket);
        stompClient.debug = null;

        stompClient.connect({}, () => {
            document.getElementById("message").disabled = false;
            document.getElementById("sendBtn").disabled = false;

            stompClient.subscribe("/topic/messages", message => {
                const msg = JSON.parse(message.body);
                if (!msg.groupId || msg.groupId === selectedGroup) {
                    let li = document.getElementById(msg.id);
                    if (!li) {
                        li = document.createElement("li");
                        li.id = msg.id;
                        li.dataset.group = msg.groupId;
                        document.getElementById("messages").appendChild(li);
                    }
                    li.innerHTML = `${msg.sender}: <span class="content">${msg.deleted ? "[deleted]" : msg.content}</span>` +
                                   `${msg.edited ? " <em>[edited]</em>" : ""} <span class="status">(${msg.status})</span>`;
                    if (msg.sender === username && !msg.deleted) {
                        const safeContent = msg.content.replace(/'/g, "\\'");
                        li.innerHTML += ` <button onclick="editMessage('${msg.id}', '${safeContent}')">Edit</button>` +
                                        ` <button onclick="deleteMessage('${msg.id}')">Delete</button>`;
                    }
                }
            });

            stompClient.subscribe("/topic/status", update => {
                const statusUpdate = JSON.parse(update.body);
                const li = document.getElementById(statusUpdate.messageId);
                if (li) {
                    const statusSpan = li.querySelector('.status');
                    if (statusSpan) {
                        statusSpan.innerText = `(${statusUpdate.status})`;
                    }
                }
            });

            stompClient.subscribe("/topic/typing", status => {
                const typing = JSON.parse(status.body);
                document.getElementById("typingIndicator").innerText =
                    typing.typing ? `${typing.sender} is typing...` : "";
            });

            stompClient.subscribe("/user/queue/signal", message => {
                handleSignal(JSON.parse(message.body));
            });

            stompClient.subscribe("/topic/online", message => {
                const status = JSON.parse(message.body);
                onlineUsers[status.username] = status.online;
                renderOnlineUsers();
            });

            stompClient.send("/app/online", {}, JSON.stringify({
                username: username,
                online: true
            }));
        });
    }

    function sendMessage() {
        const input = document.getElementById("message");
        const content = input.value.trim();
        if (!content || !selectedGroup || !stompClient?.connected) return;
        const msg = {
            sender: username,
            content: content,
            groupId: selectedGroup
        };
        stompClient.send("/app/sendMessage", {}, JSON.stringify(msg));
        input.value = "";
        sendTyping(false);
    }

    function sendTyping(isTyping = null) {
        if (!stompClient?.connected) return;
        const input = document.getElementById("message").value.trim();
        const typing = isTyping !== null ? isTyping : input.length > 0;
        stompClient.send("/app/typing", {}, JSON.stringify({
            sender: username,
            typing: typing
        }));
    }

    function editMessage(id, currentContent) {
        const newContent = prompt("Edit your message:", currentContent);
        if (newContent) {
            stompClient.send("/app/editMessage", {}, JSON.stringify({
                id: id,
                content: newContent.trim()
            }));
        }
    }

    function deleteMessage(id) {
        if (confirm("Are you sure you want to delete this message?")) {
            stompClient.send("/app/deleteMessage", {}, JSON.stringify({ id: id }));
        }
    }

    function renderOnlineUsers() {
        const userList = document.getElementById("onlineUsers");
        userList.innerHTML = '';
        Object.entries(onlineUsers).forEach(([user, online]) => {
            if (online) {
                const li = document.createElement("li");
                li.innerText = user;
                userList.appendChild(li);
            }
        });
    }

    function createGroup() {
        const name = document.getElementById("newGroupName").value.trim();
        if (!name || !stompClient?.connected) return;

        // You must provide at least one member
        const members = [username]; // Add more members from UI later

        stompClient.send("/app/createGroup", {}, JSON.stringify({
            name: name,
            members: members,
            createdBy: username
        }));

        alert("Group created. Reload page to see it.");
    }


    document.getElementById("groupSelect").addEventListener("change", (e) => {
        selectedGroup = e.target.value;
        const msgs = document.querySelectorAll("#messages li");
        msgs.forEach(li => {
            li.style.display = (li.dataset.group === selectedGroup) ? "list-item" : "none";
        });
    });


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
