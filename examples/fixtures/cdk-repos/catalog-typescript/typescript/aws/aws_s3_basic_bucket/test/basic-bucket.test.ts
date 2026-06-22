import { App, Stack } from 'aws-cdk-lib';
import { Template } from 'aws-cdk-lib/assertions';
import { BasicBucket } from '../lib/basic-bucket';

describe('BasicBucket', () => {
  it('creates encrypted bucket', () => {
    const app = new App();
    const stack = new Stack(app, 'Test');
    new BasicBucket(stack, 'Basic');
    const template = Template.fromStack(stack);
    template.resourceCountIs('AWS::S3::Bucket', 1);
    template.hasResourceProperties('AWS::S3::Bucket', {
      BucketEncryption: {
        ServerSideEncryptionConfiguration: [
          { ServerSideEncryptionByDefault: { SSEAlgorithm: 'AES256' } },
        ],
      },
    });
  });
});
