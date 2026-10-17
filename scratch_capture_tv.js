const fs = require('fs');

async function main() {
  const listResp = await fetch('http://localhost:62409/json');
  const pages = await listResp.json();
  console.log('Pages:', pages);
  const target = pages.find(p => p.type === 'page' && p.url.includes('com.pax.hospitality.tv'));
  if (!target || !target.webSocketDebuggerUrl) {
    console.log('Target not found');
    return;
  }
  
  const ws = new WebSocket(target.webSocketDebuggerUrl);
  ws.onopen = () => {
    ws.send(JSON.stringify({
      id: 1,
      method: 'Page.captureScreenshot',
      params: { format: 'png' }
    }));
  };
  ws.onmessage = (msg) => {
    const data = JSON.parse(msg.data);
    if (data.id === 1 && data.result && data.result.data) {
      fs.writeFileSync('tv_screen_new.png', Buffer.from(data.result.data, 'base64'));
      console.log('Saved tv_screen_new.png (' + fs.statSync('tv_screen_new.png').size + ' bytes)');
      ws.close();
    }
  };
  ws.onerror = (e) => console.log('WS error:', e);
}

main().catch(console.error);
