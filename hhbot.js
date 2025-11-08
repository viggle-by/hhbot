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
