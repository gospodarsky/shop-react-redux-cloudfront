import 'dotenv/config'
import { AzureFunction, Context, HttpRequest } from "@azure/functions"
import { BlobSASPermissions, BlobServiceClient, StorageSharedKeyCredential, generateBlobSASQueryParameters } from "@azure/storage-blob";

const httpTrigger: AzureFunction = async function (context: Context, req: HttpRequest): Promise<void> {
    try {
        const fileName = req.query.name;
        const account = process.env.AZURE_STORAGE_ACCOUNT_NAME;
        const accountKey = process.env.AZURE_STORAGE_ACCOUNT_KEY;
        const containerName = 'container';
        const sharedKeyCredential = new StorageSharedKeyCredential(
            account,
            accountKey,
        );
        const blobServiceClient = new BlobServiceClient(
            `https://${account}.blob.core.windows.net`,
            sharedKeyCredential,
        );
        const containerClient = blobServiceClient.getContainerClient(containerName);
        const blobClient = containerClient.getBlobClient(fileName);
        const sasToken = generateBlobSASQueryParameters(
            {
                containerName,
                blobName: fileName,
                permissions: BlobSASPermissions.parse('rwc'), // read, write
                startsOn: new Date(),
                expiresOn: new Date(new Date().valueOf() + 86400),
            },
            sharedKeyCredential,
        ).toString();
        const sasUrl = blobClient.url + '?' + sasToken;
        context.res = {
            status: 200,
            body: {
                sasToken,
                sasUrl,
                url: blobClient.url,
            },
        };
    } catch (e) {
        context.log(e);
        context.res = {
            status: 500,
            body: {
                error: e.message,
            },
        };
    }
};

export default httpTrigger;