import { AzureFunction, Context } from '@azure/functions';
import { productContainer } from '../cosmo-db';
import { FeedResponse } from '@azure/cosmos';
import { Product } from '../models';

const httpTrigger: AzureFunction = async function (
    context: Context,
): Promise<void> {
    const productsResponse: FeedResponse<Product> = await productContainer.items.query('SELECT * FROM products').fetchAll();
    const { resources: products } = productsResponse;

    context.res = {
        status: 200,
        body: products,
        headers: {
            'Content-Type': 'application/json',
        },
    };
};

export default httpTrigger;