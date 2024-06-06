import { AzureFunction, Context } from '@azure/functions';
import { productContainer, stocksContainer } from '../cosmo-db';
import { FeedResponse } from '@azure/cosmos';
import { Product, Stock } from '../models';

const httpTrigger: AzureFunction = async function (
    context: Context,
): Promise<void> {
    const productsResponse: FeedResponse<Product> = await productContainer.items.query('SELECT * FROM products').fetchAll();
    const stocksResponse: FeedResponse<Stock> = await stocksContainer.items.query('SELECT * FROM stocks').fetchAll();
    const { resources: products } = productsResponse;
    const { resources: stocks } = stocksResponse;
    const response = products.map(({ id, title, description, price }) => ({
        id,
        title,
        description,
        price,
        count: stocks.find(stock => stock.product_id === id)?.count ?? 0
    }));

    context.res = {
        status: 200,
        body: response,
        headers: {
            'Content-Type': 'application/json',
        },
    };
};

export default httpTrigger;