import { AzureFunction, Context, HttpRequest } from '@azure/functions';
import { productContainer, stocksContainer } from '../cosmo-db';
import { FeedResponse } from '@azure/cosmos';
import { Product, Stock } from '../models';

const httpTrigger: AzureFunction = async function (
    context: Context,
    req: HttpRequest
): Promise<void> {
    const productId = req.params.productId;
    const productResponse: FeedResponse<Product> = await productContainer.items.query(`SELECT * FROM p WHERE p.id = "${productId}"`).fetchAll();
    const stockResponse: FeedResponse<Stock> = await stocksContainer.items.query(`SELECT * FROM s WHERE s.product_id = "${productId}"`).fetchAll();
    const { resources: product } = productResponse;
    const { resources: stock } = stockResponse;
    const response = {
        title: product[0].title,
        description: product[0].description,
        price: product[0].price,
        id: product[0].id,
        count: stock[0]?.count ?? 0
    };

    context.res = {
        status: 200,
        body: response,
        headers: {
            'Content-Type': 'application/json',
        },
    };
};

export default httpTrigger;