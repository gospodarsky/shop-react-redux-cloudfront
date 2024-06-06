import { AzureFunction, Context, HttpRequest } from '@azure/functions';
import { productContainer, stocksContainer } from '../cosmo-db';
import { faker } from "@faker-js/faker";
import { Product, Stock } from '../models';
import { ItemResponse } from '@azure/cosmos';

const httpTrigger: AzureFunction = async function (
  context: Context,
  req: HttpRequest,
): Promise<void> {
  const { count, ...newProduct} = req.body;
  try {
    const productResponse: ItemResponse<Product> = await productContainer.items.create({ id: faker.string.uuid(), ...newProduct });
    const { resource: product } = productResponse;
    const stockResponse: ItemResponse<Stock> = await stocksContainer.items.create({ product_id: product.id, count: count ?? 0 });
    const { resource: stock } = stockResponse;
    context.res = {
      status: 201,
      body: {
        ...product,
        count: stock.count
      },
      headers: {
        'Content-Type': 'application/json',
      },
    };
  } catch (error) {
    console.error('Failed to create new product:', error);

    context.res = {
      status: 500,
      body: `Failed to create new product: ${error.message}`,
    };
  }
};

export default httpTrigger;