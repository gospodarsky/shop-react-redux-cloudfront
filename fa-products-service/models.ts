export type Product = {
  id: string; // UUID, primary and partition key
  title: string;
  description: string;
  price: number;
}

export type Stock = {
  product_id: string; // primary and partition key
  count: number;
}