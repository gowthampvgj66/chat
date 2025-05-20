<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<!DOCTYPE html>
<html>
<head>
    <title>WebRTC Chat</title>
    <script src="https://cdn.jsdelivr.net/npm/sockjs-client@1/dist/sockjs.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/stompjs@2.3.3/lib/stomp.min.js"></script>
</head>
<body>
    <h2>WebRTC Chat + Video Call</h2>

    <div>
        <input type="text" id="message" placeholder="Type a message..." oninput="sendTyping()"/>
        <button onclick="sendMessage()">Send</button>
        <p id="typingIndicator"></p>
    </div>

    <div>
        <button onclick="startAudioCall()">Start Audio Call</button>
        <button onclick="startVideoCall()">Start Video Call</button>
        <button onclick="endCall()">End Call</button>
    </div>

    <video id="localVideo" autoplay muted style="width: 300px; height: 200px;"></video>
    <video id="remoteVideo" autoplay style="width: 300px; height: 200px;"></video>

    <ul id="messages"></ul>

    <script>
        let stompClient = null;
        let localConnection;
        let localStream;

        const username = prompt("Enter your username:");
        const peerUsername = prompt("Enter peer username:");

        function connectWebSocket() {
            const socket = new SockJS('/ws');
            stompClient = Stomp.over(socket);
            stompClient.connect({}, () => {
                console.log("Connected");

                stompClient.subscribe("/topic/messages", message => {
                    const msg = JSON.parse(message.body);
                    const li = document.createElement("li");
                    li.innerText = `${msg.sender}: ${msg.content}`;
                    document.getElementById("messages").appendChild(li);
                });

                stompClient.subscribe("/topic/typing", status => {
                    const typing = JSON.parse(status.body);
                    document.getElementById("typingIndicator").innerText =
                        typing.typing ? `${typing.username} is typing...` : "";
                });

                stompClient.subscribe("/user/queue/signal", message => {
                    handleSignal(JSON.parse(message.body));
                });
            });
        }

        function sendMessage() {
            const content = document.getElementById("message").value;
            stompClient.send("/app/sendMessage", {}, JSON.stringify({
                sender: username,
                content: content
            }));
            document.getElementById("message").value = "";
        }

        function sendTyping() {
            stompClient.send("/app/typing", {}, JSON.stringify({
                username: username,
                typing: true
            }));
        }

        async function startCall(videoEnabled = false) {
            const constraints = videoEnabled ? { audio: true, video: true } : { audio: true };
            localConnection = new RTCPeerConnection();
            localStream = await navigator.mediaDevices.getUserMedia(constraints);

            localStream.getTracks().forEach(track => {
                localConnection.addTrack(track, localStream);
            });

            if (videoEnabled) {
                document.getElementById("localVideo").srcObject = localStream;
            }

            localConnection.onicecandidate = e => {
                if (e.candidate) {
                    sendSignal({
                        type: "ice",
                        candidate: JSON.stringify(e.candidate),
                        sender: username,
                        receiver: peerUsername,
                        videoEnabled
                    });
                }
            };

            localConnection.ontrack = event => {
                document.getElementById("remoteVideo").srcObject = event.streams[0];
            };

            const offer = await localConnection.createOffer();
            await localConnection.setLocalDescription(offer);

            sendSignal({
                type: "offer",
                sdp: JSON.stringify(offer),
                sender: username,
                receiver: peerUsername,
                videoEnabled
            });
        }

        async function handleSignal(msg) {
            if (msg.type === "offer") {
                localConnection = new RTCPeerConnection();
                localStream = await navigator.mediaDevices.getUserMedia(
                    msg.videoEnabled ? { audio: true, video: true } : { audio: true }
                );

                localStream.getTracks().forEach(track => {
                    localConnection.addTrack(track, localStream);
                });

                if (msg.videoEnabled) {
                    document.getElementById("localVideo").srcObject = localStream;
                }

                localConnection.onicecandidate = e => {
                    if (e.candidate) {
                        sendSignal({
                            type: "ice",
                            candidate: JSON.stringify(e.candidate),
                            sender: username,
                            receiver: msg.sender,
                            videoEnabled: msg.videoEnabled
                        });
                    }
                };

                localConnection.ontrack = event => {
                    document.getElementById("remoteVideo").srcObject = event.streams[0];
                };

                await localConnection.setRemoteDescription(new RTCSessionDescription(JSON.parse(msg.sdp)));
                const answer = await localConnection.createAnswer();
                await localConnection.setLocalDescription(answer);

                sendSignal({
                    type: "answer",
                    sdp: JSON.stringify(answer),
                    sender: username,
                    receiver: msg.sender,
                    videoEnabled: msg.videoEnabled
                });

            } else if (msg.type === "answer") {
                await localConnection.setRemoteDescription(new RTCSessionDescription(JSON.parse(msg.sdp)));
            } else if (msg.type === "ice") {
                const candidate = new RTCIceCandidate(JSON.parse(msg.candidate));
                localConnection.addIceCandidate(candidate);
            } else if (msg.type === "timeout") {
                alert("Call not answered.");
            } else if (msg.type === "end") {
                endCall(true);
                alert("Call ended by peer.");
            }
        }

        function sendSignal(msg) {
            stompClient.send("/app/signal", {}, JSON.stringify(msg));
        }

        function startAudioCall() {
            startCall(false);
        }

        function startVideoCall() {
            startCall(true);
        }

        function endCall(fromRemote = false) {
            if (localConnection) localConnection.close();
            if (localStream) {
                localStream.getTracks().forEach(track => track.stop());
            }

            document.getElementById("localVideo").srcObject = null;
            document.getElementById("remoteVideo").srcObject = null;

            if (!fromRemote) {
                sendSignal({
                    type: "end",
                    sender: username,
                    receiver: peerUsername
                });
            }
        }

        connectWebSocket();
    </script>
</body>
</html>
