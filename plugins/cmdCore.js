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
