import * as s3 from 'aws-cdk-lib/aws-s3';
import { Construct } from 'constructs';

export interface BasicBucketProps {
  readonly bucketName?: string;
}

export class BasicBucket extends Construct {
  public readonly bucket: s3.Bucket;

  constructor(scope: Construct, id: string, props: BasicBucketProps = {}) {
    super(scope, id);
    this.bucket = new s3.Bucket(this, 'Bucket', {
      bucketName: props.bucketName,
      encryption: s3.BucketEncryption.S3_MANAGED,
    });
  }
}
