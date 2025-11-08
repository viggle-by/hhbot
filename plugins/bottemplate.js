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
