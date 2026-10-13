// Read only declared vocabulary objects using the reference project's existing
// storage connection. Credentials stay in that process and are never exported.
const fs = require('node:fs');
const path = require('node:path');
const {createRequire} = require('node:module');
const {verifyMediaBytes} = require('./retained_media.cjs');

function privateMediaSource({reference, root, allowDownload}) {
  const cache = path.join(root, 'output/reference-media');
  let client, GetObjectCommand, bucket;
  let downloaded = 0;
  async function find(record) {
    if (!record) return null;
    if (!['protected/audio/vocabulary/', 'protected/images/vocabulary/']
        .some(prefix => record.key?.startsWith(prefix)) || record.key.includes('..')) {
      throw new Error('Invalid private vocabulary media key');
    }
    for (const file of [path.join(reference, record.key), path.join(cache, record.key)]) {
      if (fs.existsSync(file) && fs.statSync(file).isFile()) {
        verifyMediaBytes(fs.readFileSync(file), record, record.key);
        return file;
      }
    }
    if (!allowDownload) return null;
    if (!client) {
      const req = createRequire(path.join(reference, 'package.json'));
      req('@next/env').loadEnvConfig(reference);
      const env = process.env;
      if (!env.AWS_ENDPOINT_URL_S3?.startsWith('https://') || !env.BUCKET_NAME ||
          !env.AWS_ACCESS_KEY_ID || !env.AWS_SECRET_ACCESS_KEY) {
        throw new Error('The reference private-media storage connection is not configured');
      }
      const sdk = req('@aws-sdk/client-s3');
      GetObjectCommand = sdk.GetObjectCommand;
      bucket = env.BUCKET_NAME;
      client = new sdk.S3Client({endpoint:env.AWS_ENDPOINT_URL_S3,
        region:env.AWS_REGION || 'auto', forcePathStyle:true,
        credentials:{accessKeyId:env.AWS_ACCESS_KEY_ID, secretAccessKey:env.AWS_SECRET_ACCESS_KEY},
        maxAttempts:3});
    }
    let bytes;
    try {
      const response = await client.send(new GetObjectCommand({Bucket:bucket, Key:record.key}),
        {abortSignal:AbortSignal.timeout(45000)});
      bytes = Buffer.from(await response.Body.transformToByteArray());
    } catch (error) {
      throw new Error(`Cannot read declared vocabulary media (${error.name}, HTTP ${error.$metadata?.httpStatusCode??'unavailable'}): ${record.key}`);
    }
    verifyMediaBytes(bytes, record, record.key);
    const destination = path.join(cache, record.key);
    fs.mkdirSync(path.dirname(destination), {recursive:true});
    fs.writeFileSync(destination+'.tmp', bytes);
    fs.renameSync(destination+'.tmp', destination);
    downloaded++;
    if (downloaded % 100 === 0) process.stdout.write(`Fetched ${downloaded} verified private vocabulary files.\n`);
    return destination;
  }
  return {find, close:() => client?.destroy(), downloads:() => downloaded};
}

module.exports = {privateMediaSource};
