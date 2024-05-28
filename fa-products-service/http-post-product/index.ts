import { AzureFunction, Context, HttpRequest } from '@azure/functions';
import { productContainer } from '../cosmo-db';
import { faker } from "@faker-js/faker";

const httpTrigger: AzureFunction = async function (
  context: Context,
  req: HttpRequest,
): Promise<void> {
  const { ...newProduct } = req.body;
  console.log({ newProduct });
  try {
    const { resource: createdProduct } = await productContainer.items.create({ id: faker.string.uuid(), ...newProduct });
    console.log({ createdProduct });
    context.res = {
      status: 201,
      body: {
        ...createdProduct
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