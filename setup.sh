#!/bin/bash
echo "Setting up hhbot project..."

# Initialize npm
npm init -y

# Install dependencies
npm install mineflayer mineflayer-pathfinder prismarine-viewer vec3 express

# Create folders
mkdir -p plugins viewers

# Create config.json
cat > config.json <<'EOF'
{
  "customChat": {
    "enabled": true,
    "onlyUseWhenNecessary": false,
    "format": {
      "color": "#FF99DD",
      "translate": "[%s] %s › %s",
      "with": [
        {
          "color": "#FFCCEE",
          "click_event": {
            "action": "open_url",
            "url": "https://code.chipmunk.land/7cc5c4f330d47060/chipmunkmod"
          },
          "hover_event": {
            "action": "show_text",
            "value": {
              "color": "white",
              "text": "Click to open ChipmunkMod source code"
            }
          },
          "text": "ChipmunkMod"
        },
        {
          "color": "#FFCCEE",
          "selector": "@s"
        },
        {
          "color": "white",
          "click_event": {
            "action": "copy_to_clipboard",
            "value": "MESSAGE"
          },
          "hover_event": {
            "action": "show_text",
            "value": {
              "color": "white",
              "text": "Click to copy message"
            }
          },
          "text": "MESSAGE"
        }
      ]
    }
  },
  "bots": [
    { "host":"chipmunk.land", "port":25565, "username":"hhbot1", "version":"1.19.1", "viewerPort":3001 },
    { "host":"kaboom.pw", "port":25565, "username":"hhbot2", "version":"1.19.1", "viewerPort":3002 }
  ]
}
EOF

# Create plugins/cmdCore.js
cat > plugins/cmdCore.js <<'EOF'
const vec3 = require("vec3");

function injectTo(bot) {
    const cmdCore = {
        S: null,
        E: null,
        relativePos: new vec3(0,0,0),

        isCmdCore(pos) {
            return pos.x >= this.S.x && pos.x <= this.E.x &&
                   pos.y >= this.S.y && pos.y <= this.E.y &&
                   pos.z >= this.S.z && pos.z <= this.E.z;
        },

        run(cmd) {
            this.relativePos.x++;
            if(this.relativePos.x >= 16){ this.relativePos.x=0; this.relativePos.y++; }
            if(this.relativePos.y >= 5){ this.relativePos.y=0; this.relativePos.z++; }
            if(this.relativePos.z >=16){ this.relativePos.z=0; }

            bot._client.write("update_command_block", {
                location: {x:this.S.x+this.relativePos.x, y:this.S.y+this.relativePos.y, z:this.S.z+this.relativePos.z},
                command: cmd,
                mode: 1,
                flags: 0b100
            });
        },

        refillCmdCore() {
            bot.chat(`/fill ${this.S.x} ${this.S.y} ${this.S.z} ${this.E.x} ${this.E.y} ${this.E.z} minecraft:repeating_command_block{CustomName:'{"text":"mBot","color":"red","bold":true}'} replace`);
            bot.emit("cmdCore_refilled");
        }
    };

    bot.once("spawn", () => {
        cmdCore.S = new vec3(Math.floor(bot.entity.position.x/16)*16, 0, Math.floor(bot.entity.position.z/16)*16);
        cmdCore.E = cmdCore.S.clone().translate(16,5,16).subtract(new vec3(1,1,1));
        cmdCore.refillCmdCore();
        setTimeout(()=>{ cmdCore.run(`tellraw @a "cmdCore ready!"`) }, 2000);
    });

    bot.cmdCore = cmdCore;
    return cmdCore;
}

module.exports = { injectTo };
EOF

# Create plugins/bottemplate.js
cat > plugins/bottemplate.js <<'EOF'
const mineflayer = require("mineflayer");
const { pathfinder, Movements } = require("mineflayer-pathfinder");
const { mineflayer: mineViewer } = require("prismarine-viewer");

function createTemplateBot(options, config) {
    const bot = mineflayer.createBot({
        host: options.host,
        port: options.port,
        username: options.username,
        version: options.version
    });

    bot.loadPlugin(pathfinder);

    bot.once("spawn", () => {
        const mcData = require("minecraft-data")(bot.version);
        bot.pathfinder.setMovements(new Movements(bot, mcData));
        mineViewer(bot, { port: options.viewerPort, firstPerson: true });
    });

    // Simple WASD movement
    bot.setControlState("forward", true);

    // Chat handling
    bot.on("chat", (username, message) => {
        if(message.startsWith("!")) handleCommand(username, message, bot, config);
    });

    bot.sendChatFromViewer = (msg) => bot.chat(msg);
    bot.subscribeChat = (cb) => bot.on("chat", (user,msg)=>cb(`[${user}] ${msg}`));

    return bot;
}

function handleCommand(username, message, bot, config) {
    if(message.startsWith("!generatecustombot")) {
        const args = message.split(" ");
        if(args.length<4) return bot.chat("Usage: !generatecustombot <host> <port> <username>");
        const newBotOpts = {
            host: args[1],
            port: parseInt(args[2]),
            username: args[3],
            version: bot.version,
            viewerPort: bot.viewerPort + 1
        };
        const { generateCustomBot } = require("../hhbot.js");
        generateCustomBot(newBotOpts);
        bot.chat(`Generated bot ${args[3]} at ${args[1]}:${args[2]}`);
    }
}

module.exports = createTemplateBot;
EOF

# Create hhbot.js
cat > hhbot.js <<'EOF'
const express = require('express');
const app = express();
app.use(express.json());

const createTemplateBot = require('./plugins/bottemplate.js');
const { injectTo } = require('./plugins/cmdCore.js');
const config = require('./config.json');

const bots = [];

for (const opts of config.bots) {
  const bot = createTemplateBot(opts, config);
  injectTo(bot);
  bots.push(bot);
}

function generateCustomBot(opts) {
  const bot = createTemplateBot(opts, config);
  injectTo(bot);
  bots.push(bot);
  console.log(`Generated bot ${opts.username} at ${opts.host}:${opts.port}`);
  return bot;
}

// Viewer endpoints
app.get('/viewer/:port', (req,res) => {
  res.sendFile(__dirname+'/viewers/index.html');
});

app.get('/viewer/:port/chatstream', (req,res)=>{
  const port = parseInt(req.params.port);
  const bot = bots.find(b => b.viewerPort===port);
  if(!bot) return res.sendStatus(404);
  res.writeHead(200, {'Content-Type':'text/event-stream','Cache-Control':'no-cache','Connection':'keep-alive'});
  const sendMessage = msg=>res.write(`data: ${msg}\n\n`);
  bot.subscribeChat(sendMessage);
  const interval = setInterval(()=>res.write('\n'),20000);
  req.on('close',()=>clearInterval(interval));
});

app.post('/viewer/:port/send', (req,res)=>{
  const port = parseInt(req.params.port);
  const bot = bots.find(b=>b.viewerPort===port);
  if(bot && req.body.message) bot.sendChatFromViewer(req.body.message);
  res.sendStatus(200);
});

app.listen(3000, ()=>console.log('Server running on http://localhost:3000'));

module.exports = { generateCustomBot };
EOF

# Create viewers/index.html
cat > viewers/index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"><title>hhbot Viewer</title>
<style>
body { margin:0; font-family:sans-serif; display:flex; flex-direction:column; height:100vh; background:#111; color:#fff; }
#iframe { flex:1; }
#messages { flex:1; overflow-y:auto; padding:5px; background:#222; }
#chatbox { display:flex; padding:5px; }
#chatbox input { flex:1; padding:8px; font-size:16px; }
#chatbox button { padding:8px 16px; font-size:16px; }
</style>
</head>
<body>
<iframe id="iframe" src=""></iframe>
<div id="messages"></div>
<div id="chatbox">
<input id="msg" type="text" placeholder="Type a message..." />
<button onclick="sendMessage()">Send</button>
</div>
<script>
const messages = document.getElementById('messages');
const urlParams = new URLSearchParams(window.location.search);
const port = urlParams.get('port') || 3001;

const evtSource = new EventSource('/viewer/' + port + '/chatstream');
evtSource.onmessage = e => {
  const div = document.createElement('div');
  div.innerHTML = e.data;
  messages.appendChild(div);
  messages.scrollTop = messages.scrollHeight;
};

function sendMessage() {
  const msg = document.getElementById('msg').value;
  if(!msg) return;
  fetch('/viewer/'+port+'/send', { method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({message:msg}) });
  document.getElementById('msg').value='';
}
</script>
</body>
</html>
EOF

echo "Setup complete. Run 'node hhbot.js' to start the bots."

