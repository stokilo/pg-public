import { PutObjectCommand, S3Client, S3 } from '@aws-sdk/client-s3'
import { Upload } from '@aws-sdk/lib-storage'
import { ReadStream } from 'fs'

export async function saveTextObject(bucketName: string, bucketKey: string, textContent: string) {
  const s3Client = new S3Client({ region: process.env.REGION })
  const uploadParams = {
    Bucket: bucketName,
    Key: bucketKey,
    Body: textContent,
  }
  await s3Client.send(new PutObjectCommand(uploadParams))
}

export async function saveBinaryObject(bucketName: string, bucketKey: string, stream: ReadStream) {
  const uploadParams = {
    Bucket: bucketName,
    Key: bucketKey,
    Body: stream,
  }

  const parallelUploads3 = new Upload({
    client: new S3({}) || new S3Client({}),
    params: uploadParams,
    tags: [],
    queueSize: 4,
    partSize: 1024 * 1024 * 5,
    leavePartsOnError: false,
  })

  await parallelUploads3.done()
}
