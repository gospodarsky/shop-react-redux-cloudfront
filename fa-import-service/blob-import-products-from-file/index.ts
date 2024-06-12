import { AzureFunction, Context } from "@azure/functions";
import { parse } from 'csv-parse';

const blobTrigger: AzureFunction = async function (context: Context, myBlob: any): Promise<void> {
    const records = parse(context.bindings.blob, {
        columns: true,
        skip_empty_lines: true,
      });
    
      context.log(context.bindings);
    
      records.forEach((record) => {
        context.log(`Record: ${JSON.stringify(record)}`);
      });
};

export default blobTrigger;
