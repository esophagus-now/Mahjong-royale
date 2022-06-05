var ws = null;
var animate = true;
var gamestate = {
    role: "(unassigned)",
    table: ""
};

function draw_game_state() {
    var s = document.getElementById("status");
    s.innerText = gamestate.role;
    var t = document.getElementById("drawzone");
    t.innerText = gamestate.table;
}

function input_submit() {
    var n = document.getElementById("in");
    var txt = n.value;
    n.value = "";
    if (ws !== null) {
        ws.send(txt);
    }
}

function anim_loop_wrapped(timestamp) {
    //console.log(timestamp - last_timestamp);

    draw_game_state();
    
    if (animate) {
        last_timestamp = timestamp;
        requestAnimationFrame(anim_loop_wrapped);
    }
}

function anim_loop(timestamp) {
    last_timestamp = timestamp;
    window.requestAnimationFrame(anim_loop_wrapped);
}


function i_am_loaded() {
    var n = document.getElementById("in");
    n.onkeypress = function(e) {
        if (e.key == "Enter") {
            input_submit();
            e.preventDefault();
        }
    };

    ws = new WebSocket("wss://Mahjong-royale.mahkoe.repl.co/mahjong.cgi");
    ws.onmessage = function(e) {
        console.log(e);
        var str = e.data;
        str = str.split(str[0]);
        if (str.length >= 3) {
            gamestate[str[1]] = str[2];
        }
    };

    ws.onopen = function(e) {ws.send("1.0");};

    anim_loop();
}