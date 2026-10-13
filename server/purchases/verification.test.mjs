import test from 'node:test';
import assert from 'node:assert/strict';
import {generateKeyPairSync,verify} from 'node:crypto';
import {AppleVerifier,GoogleVerifier,validateRequest,signEntitlement} from './verification.mjs';
import {createPurchaseServer} from './server.mjs';
import {Type} from '@apple/app-store-server-library';

const monthly='wortgarten_premium_monthly',life='wortgarten_premium_lifetime';
const now=Date.parse('2026-10-10T00:00:00Z');
const request={productId:monthly,source:'google_play',proof:'a-valid-store-purchase-token'};
test('invalid products and untrusted request shapes are rejected',()=>{
  for(const value of [{...request,productId:'other_app'}, {...request,proof:''},
    {...request,source:'client_json'}, {...request,transactionId:'../admin'},null])assert.throws(()=>validateRequest(value));
  assert.equal(validateRequest(request),request);
});
test('signed grants are Ed25519, proof-bound and tamper evident',()=>{
  const {privateKey,publicKey}=generateKeyPairSync('ed25519');
  const token=signEntitlement({productId:monthly,active:true,validUntil:now/1000+86400},request,privateKey,now);
  const [payload,signature]=token.split('.');
  assert.equal(verify(null,Buffer.from(payload),publicKey,Buffer.from(signature,'base64url')),true);
  assert.equal(verify(null,Buffer.from(payload+'x'),publicKey,Buffer.from(signature,'base64url')),false);
  const claims=JSON.parse(Buffer.from(payload,'base64url'));
  assert.equal(claims.app,'wortgarten');assert.equal(claims.proofHash.length,64);
  assert.throws(()=>signEntitlement({productId:life,active:true,validUntil:null},request,privateKey));
});
test('Google pending, paused and held subscriptions do not grant access',async()=>{
  let state='SUBSCRIPTION_STATE_PENDING';
  const verifier=new GoogleVerifier({packageName:'com.wortgarten.german_vocabulary',now:()=>now,
    client:{request:async()=>({data:{subscriptionState:state,lineItems:[{productId:monthly,expiryTime:'2026-11-10T00:00:00Z'}]}})}});
  for(const s of ['SUBSCRIPTION_STATE_PENDING','SUBSCRIPTION_STATE_ON_HOLD','SUBSCRIPTION_STATE_PAUSED','SUBSCRIPTION_STATE_EXPIRED']){
    state=s;assert.equal((await verifier.verify(request)).active,false);
  }
  for(const s of ['SUBSCRIPTION_STATE_ACTIVE','SUBSCRIPTION_STATE_CANCELED','SUBSCRIPTION_STATE_IN_GRACE_PERIOD']){
    state=s;assert.equal((await verifier.verify(request)).active,true);
  }
});
test('Google expiration and product mismatches do not grant access',async()=>{
  const verifier=new GoogleVerifier({packageName:'expected.app',now:()=>now,
    client:{request:async()=>({data:{subscriptionState:'SUBSCRIPTION_STATE_ACTIVE',lineItems:[{productId:monthly,expiryTime:'2026-09-10T00:00:00Z'}]}})}});
  assert.equal((await verifier.verify(request)).active,false);
  verifier.client={request:async()=>({data:{lineItems:[{productId:'foreign_product',expiryTime:'2027-01-01'}]}})};
  await assert.rejects(()=>verifier.verify(request));
});
test('Google lifetime requires completed purchase state',async()=>{
  let purchaseState=2;
  const verifier=new GoogleVerifier({packageName:'expected.app',client:{request:async()=>({data:{purchaseState}})}});
  const input={...request,productId:life};
  assert.equal((await verifier.verify(input)).active,false);
  purchaseState=0;assert.equal((await verifier.verify(input)).active,true);
  purchaseState=1;assert.equal((await verifier.verify(input)).active,false);
});
test('Apple verifies signatures, bundle, transaction identity and refunds',async()=>{
  let revoked=false,bundle='expected.app';
  const verifier=new AppleVerifier({bundleId:'expected.app',
    verifier:{verifyAndDecodeTransaction:async()=>({productId:life,bundleId:bundle,transactionId:'123',type:Type.NON_CONSUMABLE,revocationDate:revoked?now:undefined})},
    client:{getTransactionInfo:async()=>({signedTransactionInfo:'signed.current.receipt'})}});
  const input={productId:life,source:'app_store',proof:'signed.store.receipt',transactionId:'123'};
  assert.equal((await verifier.verify(input)).active,true);
  revoked=true;assert.equal((await verifier.verify(input)).active,false);
  bundle='foreign.app';await assert.rejects(()=>verifier.verify(input));
  bundle='expected.app';await assert.rejects(()=>verifier.verify({...input,transactionId:'456'}));
  verifier.verifier={verifyAndDecodeTransaction:async()=>{throw Error('signature invalid')}};
  await assert.rejects(()=>verifier.verify(input));
});
test('Apple grace periods use signed renewal expiry',async()=>{
  const verifier=new AppleVerifier({bundleId:'expected.app',now:()=>now,
    verifier:{verifyAndDecodeTransaction:async()=>({productId:monthly,bundleId:'expected.app',transactionId:'123',type:Type.AUTO_RENEWABLE_SUBSCRIPTION,expiresDate:now-1000}),
      verifyAndDecodeRenewalInfo:async()=>({gracePeriodExpiresDate:now+86400000})},
    client:{getAllSubscriptionStatuses:async()=>({data:[{lastTransactions:[{status:4,signedTransactionInfo:'current',signedRenewalInfo:'renewal'}]}]})}});
  assert.equal((await verifier.verify({productId:monthly,proof:'signed.store.receipt'})).active,true);
});
test('HTTP service fails closed without signing configuration',async()=>{
  const server=createPurchaseServer({privateKey:null,apple:null,google:null});
  await new Promise(r=>server.listen(0,'127.0.0.1',r));
  try{
    const url=`http://127.0.0.1:${server.address().port}`;
    assert.equal((await fetch(url+'/verify',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(request)})).status,503);
    assert.equal((await (await fetch(url+'/health')).json()).ready,false);
  }finally{await new Promise(r=>server.close(r));}
});
test('HTTP service returns only a signed result from the store verifier',async()=>{
  const {privateKey,publicKey}=generateKeyPairSync('ed25519');
  const server=createPurchaseServer({privateKey,apple:null,google:{verify:async()=>({productId:monthly,active:true,validUntil:now/1000+86400})}},{now:()=>now});
  await new Promise(r=>server.listen(0,'127.0.0.1',r));
  try{
    const url=`http://127.0.0.1:${server.address().port}/verify`;
    const response=await fetch(url,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(request)});
    const {entitlement}=await response.json();const [payload,signature]=entitlement.split('.');
    assert.equal(verify(null,Buffer.from(payload),publicKey,Buffer.from(signature,'base64url')),true);
    assert.equal((await fetch(url,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({...request,productId:'other_app'})})).status,400);
  }finally{await new Promise(r=>server.close(r));}
});
