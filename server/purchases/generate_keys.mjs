import {generateKeyPairSync} from 'node:crypto';
import {mkdirSync,writeFileSync} from 'node:fs';
const {privateKey,publicKey}=generateKeyPairSync('ed25519');
mkdirSync('private',{recursive:true,mode:0o700});
writeFileSync('private/entitlement-key.pem',privateKey.export({type:'pkcs8',format:'pem'}),{flag:'wx',mode:0o600});
const raw=publicKey.export({type:'spki',format:'der'}).subarray(-32).toString('base64');
console.log('Private signing key saved to private/entitlement-key.pem. Keep it on the server only.');
console.log(`ENTITLEMENT_PUBLIC_KEY=${raw}`);
