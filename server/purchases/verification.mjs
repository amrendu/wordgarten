import {createHash, sign, createPrivateKey} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {AppStoreServerAPIClient, Environment, SignedDataVerifier, Status, Type} from '@apple/app-store-server-library';
import {GoogleAuth} from 'google-auth-library';

export const products = Object.freeze({
  wortgarten_premium_weekly: 'subscription',
  wortgarten_premium_monthly: 'subscription',
  wortgarten_premium_lifetime: 'lifetime',
});
export class VerificationError extends Error {
  constructor(message, status = 400) { super(message); this.status = status; }
}
export function validateRequest(input) {
  if (!input || typeof input !== 'object' || !Object.hasOwn(products, input.productId) ||
      !['app_store', 'google_play'].includes(input.source) ||
      typeof input.proof !== 'string' || input.proof.length < 12 || input.proof.length > 60000 ||
      input.transactionId != null && (typeof input.transactionId !== 'string' ||
        !(input.source==='app_store'?/^[0-9]+$/:/^[A-Za-z0-9._-]{1,160}$/).test(input.transactionId))) {
    throw new VerificationError('Invalid purchase');
  }
  return input;
}
export function signEntitlement(result, input, privateKey, now = Date.now()) {
  if (!Object.hasOwn(products, result.productId) ||
      products[result.productId] !== products[input.productId] ||
      typeof result.active !== 'boolean' ||
      (products[result.productId] === 'subscription' && !Number.isFinite(result.validUntil)) ||
      (products[result.productId] === 'lifetime' && result.validUntil !== null)) {
    throw new VerificationError('Invalid verified result', 502);
  }
  const claims = {version:1, app:'wortgarten', productId:result.productId,
    active:result.active, issuedAt:Math.floor(now/1000), validUntil:result.validUntil,
    proofHash:createHash('sha256').update(input.proof).digest('hex')};
  const payload = Buffer.from(JSON.stringify(claims)).toString('base64url');
  return `${payload}.${sign(null, Buffer.from(payload), privateKey).toString('base64url')}`;
}

export class AppleVerifier {
  constructor({client, verifier, bundleId, now = Date.now}) {
    this.client=client;this.verifier=verifier;this.bundleId=bundleId;this.now=now;
  }
  check(transaction) {
    if (transaction.bundleId !== this.bundleId || !Object.hasOwn(products, transaction.productId)) {
      throw new VerificationError('Purchase belongs to a different app or product');
    }
  }
  async verify(input) {
    // StoreKit 2 provides Apple-signed JWS, never trust decoded client JSON.
    if (input.proof.split('.').length !== 3) throw new VerificationError('StoreKit 2 proof required');
    const original=await this.verifier.verifyAndDecodeTransaction(input.proof);
    this.check(original);
    if (original.productId!==input.productId || input.transactionId && original.transactionId!==input.transactionId) {
      throw new VerificationError('Purchase identity mismatch');
    }
    if (products[input.productId]==='lifetime') {
      if (original.type!==Type.NON_CONSUMABLE) throw new VerificationError('Permanent product required');
      // Query Apple again to see refunds/revocations after the original receipt.
      const response=await this.client.getTransactionInfo(original.transactionId);
      const current=await this.verifier.verifyAndDecodeTransaction(response.signedTransactionInfo);
      this.check(current);
      if(current.transactionId!==original.transactionId||current.productId!==input.productId||current.type!==Type.NON_CONSUMABLE)
        throw new VerificationError('Purchase identity mismatch');
      return {productId:current.productId,active:!current.revocationDate,validUntil:null};
    }
    if (original.type!==Type.AUTO_RENEWABLE_SUBSCRIPTION) throw new VerificationError('Subscription required');
    const response=await this.client.getAllSubscriptionStatuses(original.transactionId);
    let best={productId:input.productId,active:false,validUntil:0};
    for(const group of response.data??[])for(const item of group.lastTransactions??[]){
      const current=await this.verifier.verifyAndDecodeTransaction(item.signedTransactionInfo);
      this.check(current);
      if(products[current.productId]!=='subscription'||current.type!==Type.AUTO_RENEWABLE_SUBSCRIPTION)continue;
      let expiry=current.expiresDate??0;
      if(item.status===Status.BILLING_GRACE_PERIOD&&item.signedRenewalInfo){
        const renewal=await this.verifier.verifyAndDecodeRenewalInfo(item.signedRenewalInfo);
        expiry=Math.max(expiry,renewal.gracePeriodExpiresDate??0);
      }
      const active=[Status.ACTIVE,Status.BILLING_GRACE_PERIOD].includes(item.status)&&!current.revocationDate&&expiry>this.now();
      if(active&&(!best.active||expiry/1000>best.validUntil))best={productId:current.productId,active:true,validUntil:Math.floor(expiry/1000)};
    }
    return best;
  }
}

export class GoogleVerifier {
  constructor({client, packageName, now = Date.now}) {this.client=client;this.packageName=packageName;this.now=now;}
  async verify(input) {
    const base=`https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(this.packageName)}/purchases`;
    const token=encodeURIComponent(input.proof);
    if(products[input.productId]==='lifetime'){
      const {data}=await this.client.request({url:`${base}/products/${encodeURIComponent(input.productId)}/tokens/${token}`});
      return {productId:input.productId,active:data.purchaseState===0,validUntil:null};
    }
    const {data}=await this.client.request({url:`${base}/subscriptionsv2/tokens/${token}`});
    const item=(data.lineItems??[]).filter(i=>Object.hasOwn(products,i.productId)&&products[i.productId]==='subscription')
      .sort((a,b)=>Date.parse(b.expiryTime)-Date.parse(a.expiryTime))[0];
    if(!item)throw new VerificationError('Purchase belongs to a different product');
    const expiry=Date.parse(item.expiryTime);
    if(!Number.isFinite(expiry))throw new VerificationError('Invalid store expiration',502);
    const active=['SUBSCRIPTION_STATE_ACTIVE','SUBSCRIPTION_STATE_CANCELED','SUBSCRIPTION_STATE_IN_GRACE_PERIOD']
      .includes(data.subscriptionState)&&expiry>this.now();
    return {productId:item.productId,active,validUntil:Math.floor(expiry/1000)};
  }
}

export function createVerifiers(env=process.env) {
  const privateKey=env.ENTITLEMENT_KEY_FILE ? createPrivateKey(readFileSync(env.ENTITLEMENT_KEY_FILE)) : null;
  if(privateKey&&privateKey.asymmetricKeyType!=='ed25519')throw Error('An Ed25519 signing key is required');
  let apple=null;
  const bundleId=env.APPLE_BUNDLE_ID??'com.wortgarten.germanVocabulary';
  if(env.APPLE_KEY_FILE&&env.APPLE_KEY_ID&&env.APPLE_ISSUER_ID&&env.APPLE_ROOT_CERTIFICATES){
    const environment=env.APPLE_ENVIRONMENT==='Sandbox'?Environment.SANDBOX:Environment.PRODUCTION;
    if(environment===Environment.PRODUCTION&&!(Number(env.APPLE_APP_ID)>0))throw Error('Production Apple app ID is required');
    const verifier=new SignedDataVerifier(env.APPLE_ROOT_CERTIFICATES.split(',').map(p=>readFileSync(p.trim())),
      true,environment,bundleId,environment===Environment.PRODUCTION?Number(env.APPLE_APP_ID):undefined);
    apple=new AppleVerifier({verifier,bundleId,client:new AppStoreServerAPIClient(readFileSync(env.APPLE_KEY_FILE,'utf8'),
      env.APPLE_KEY_ID,env.APPLE_ISSUER_ID,bundleId,environment)});
  }
  const auth=new GoogleAuth({scopes:['https://www.googleapis.com/auth/androidpublisher']});
  const google=new GoogleVerifier({packageName:env.GOOGLE_PACKAGE_NAME??'com.wortgarten.german_vocabulary',
    client:{request:async args=>(await auth.getClient()).request(args)}});
  return {privateKey,apple,google};
}
