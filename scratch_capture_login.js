const fs = require('fs');

async function main() {
  const listResp = await fetch('http://localhost:62409/json');
  const pages = await listResp.json();
  const target = pages.find(p => p.type === 'page' && p.url.includes('com.pax.hospitality.tv'));
  if (!target || !target.webSocketDebuggerUrl) return;
  
  const ws = new WebSocket(target.webSocketDebuggerUrl);
  ws.onopen = () => {
    ws.send(JSON.stringify({
      id: 1,
      method: 'Runtime.evaluate',
      params: {
        expression: `
          (() => {
            window.App.renderLoginScreen();
            return 'login rendered';
          })()
        `
      }
    }));
  };
  ws.onmessage = (msg) => {
    const data = JSON.parse(msg.data);
    if (data.id === 1) {
      setTimeout(() => {
        ws.send(JSON.stringify({
          id: 2,
          method: 'Page.captureScreenshot',
          params: { format: 'png' }
        }));
      }, 700);
    } else if (data.id === 2 && data.result && data.result.data) {
      fs.writeFileSync('login_screen_new.png', Buffer.from(data.result.data, 'base64'));
      console.log('Saved login_screen_new.png (' + fs.statSync('login_screen_new.png').size + ' bytes)');
      ws.close();
    }
  };
}

main().catch(console.error);
