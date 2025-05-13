# MCP Examples

## Example 1: Connecting to a File System

MCP can be used to give an AI access to a file system:

```
// Initialize MCP client
const client = new MCP.Client();

// Connect to file system server
const connection = await client.connect(transport);

// Get resources
const resources = await connection.resources();
```

## Example 2: Database Access

MCP can provide secure access to databases:

```
// Read database schema
const schemaResource = await connection.readResource('db/schema');

// Execute a query
const result = await connection.callTool('query', {
  sql: 'SELECT * FROM users LIMIT 10'
});
```
