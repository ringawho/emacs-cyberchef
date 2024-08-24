// -*- mode:js -*-
import chef from "cyberchef";
import WebSocket from 'ws';

console.log(process.argv)

const port = parseInt(process.argv[2]) || 9999;

const ws = new WebSocket(`ws://127.0.0.1:${port}`);
ws.on('message', message => {
  try {
    console.log(`Received: ${message}`);
    const info = JSON.parse(message);
    let res = chef.bake(info.text, JSON.parse(info.bake));

    // const buffer = Buffer.from(res.toString(), 'binary');
    // res = buffer.toString('utf-8');

    console.log(`bake: ${res}`);
    ws.send(JSON.stringify({
      status: 0,
      message: res.toString(),
      postproc: info.postproc
    }));
  } catch (e) {
    console.error(e);
    ws.send(JSON.stringify({
      status: -1,
      message: e.stack.split('\n').slice(0, 4).join('\n')
    }));
  }
});
