import 'dotenv/config'
import { CosmosClient } from '@azure/cosmos';

const key = process.env.COSMOS_KEY;
const endpoint = process.env.COSMOS_ENDPOINT;

export const databaseId = 'test-db';
export const productsContainerId = 'products';
export const stockContainerId = 'stocks';

console.log({ key, endpoint });

export const cosmosClient = new CosmosClient({ endpoint, key });
export const database = cosmosClient.database(databaseId);
export const productContainer = database.container(productsContainerId);
export const stocks = database.container(stockContainerId);