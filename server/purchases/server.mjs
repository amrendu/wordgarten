import {createServer} from 'node:http';
import {pathToFileURL} from 'node:url';
import {createVerifiers, validateRequest, signEntitlement, VerificationError} from './verification.mjs';

export function createPurchaseServer({privateKey, apple, google}, {now=Date.now}={}) {
  const rates=new Map();
  const sweep=setInterval(()=>{for(const [ip,entry]of rates)if(entry.until<now())rates.delete(ip);},60000);
  sweep.unref();
  const server=createServer(async(req,res)=>{
    const send=(status,value)=>{
      res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});
      res.end(JSON.stringify(value));
    };
    if(req.method==='GET'&&req.url==='/health'){send(200,{ready:Boolean(privateKey)});return;}
    if(req.method!=='POST'||req.url!=='/verify'){send(404,{error:'Not found'});return;}
    const ip=req.socket.remoteAddress??'unknown';const entry=rates.get(ip);
    if(entry&&entry.until>now()&&entry.count>=60){send(429,{error:'Try again later'});return;}
    rates.set(ip,entry&&entry.until>now()?{...entry,count:entry.count+1}:{count:1,until:now()+60000});
    if(!privateKey){send(503,{error:'Purchase verification unavailable'});return;}
    try{
      if(!req.headers['content-type']?.startsWith('application/json'))throw new VerificationError('JSON required');
      let size=0;const chunks=[];
      for await(const chunk of req){size+=chunk.length;if(size>65536)throw new VerificationError('Request too large',413);chunks.push(chunk);}
      const input=validateRequest(JSON.parse(Buffer.concat(chunks).toString('utf8')));
      const verifier=input.source==='app_store'?apple:google;
      if(!verifier)throw new VerificationError('Store verification unavailable',503);
      const verified=await verifier.verify(input);
      send(200,{entitlement:signEntitlement(verified,input,privateKey,now())});
    }catch(error){
      // Never log purchase tokens, receipts, credentials or raw upstream errors.
      const status=error instanceof VerificationError?error.status:error instanceof SyntaxError?400:503;
      send(status,{error:status>=500?'Purchase verification unavailable':'Purchase could not be verified'});
    }
  });
  server.on('close',()=>clearInterval(sweep));
  return server;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
  const server=createPurchaseServer(createVerifiers());
  const port=Number(process.env.PORT??8080);
  server.listen(port,'0.0.0.0',()=>console.log(`Purchase verification listening on port ${port}.`));
}
