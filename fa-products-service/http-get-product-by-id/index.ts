import { AzureFunction, Context, HttpRequest } from '@azure/functions';
import { productContainer } from '../cosmo-db';
import { FeedResponse } from '@azure/cosmos';
import { Product } from '../models';

const httpTrigger: AzureFunction = async function (
    context: Context,
    req: HttpRequest
): Promise<void> {
    const productId = req.params.productId;
    const productResponse: FeedResponse<Product> = await productContainer.items.query(`SELECT * FROM c WHERE c.id = "${productId}"`).fetchAll();
    const { resources: product } = productResponse;

    context.res = {
        status: 200,
        body: product,
        headers: {
            'Content-Type': 'application/json',
        },
    };
};

export default httpTrigger;