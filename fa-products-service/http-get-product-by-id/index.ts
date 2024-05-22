import { AzureFunction, Context, HttpRequest } from "@azure/functions";
import { products } from '../mock';

const httpTrigger: AzureFunction = async function (context: Context, req: HttpRequest): Promise<void> {
    context.log('HTTP trigger function processed a request.');
    const productId = req.params.productId;

    context.res = {
        status: 200,
        body: products.find(({ id }) => id === productId)
    };
};

export default httpTrigger;