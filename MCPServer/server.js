#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const readline = require('readline');
const http = require('http');

// Port for HTTP server
const PORT = 3000;

// Set up the input/output streams for the Model Context Protocol
const rl = readline.createInterface({
  input: process.stdin,
  output: null,
  terminal: false
});

// Simple MCP Protocol implementation
class MCPServer {
  constructor() {
    this.resources = [
      {
        uri: 'demo/introduction.md',
        type: 'markdown',
        name: 'Introduction to MCP',
        description: 'An introduction to the Model Context Protocol'
      },
      {
        uri: 'demo/api_reference.md',
        type: 'markdown',
        name: 'API Reference',
        description: 'API Reference for the MCP Protocol'
      },
      {
        uri: 'demo/examples.md',
        type: 'markdown',
        name: 'Examples',
        description: 'Examples of using MCP'
      }
    ];
    
    // Create the demo directory and files if they don't exist
    this.initializeResources();
  }

  // Initialize the resources (files) for this demo
  initializeResources() {
    const demoDir = path.join(__dirname, 'demo');
    
    if (!fs.existsSync(demoDir)) {
      fs.mkdirSync(demoDir, { recursive: true });
    }

    // Introduction file
    fs.writeFileSync(
      path.join(demoDir, 'introduction.md'),
      `# Introduction to Model Context Protocol (MCP)

The Model Context Protocol (MCP) is an open standard for connecting AI assistants to data sources.
It enables AI models to access context from various systems, enhancing their ability to provide accurate
and relevant responses.

## Key Features

- Standardized access to external data
- Secure communication between AI models and data sources
- Support for various content types
- Cross-platform compatibility
`
    );

    // API Reference file
    fs.writeFileSync(
      path.join(demoDir, 'api_reference.md'),
      `# MCP API Reference

## Core Concepts

- **Resources**: Data objects that can be accessed by the AI
- **Content**: The actual content of resources
- **Tools**: Functions that can be called by the AI

## Basic Protocol Flow

1. Client connects to server
2. Client requests resources
3. Client reads resource content
4. Client may use tools provided by the server
`
    );

    // Examples file
    fs.writeFileSync(
      path.join(demoDir, 'examples.md'),
      `# MCP Examples

## Example 1: Connecting to a File System

MCP can be used to give an AI access to a file system:

\`\`\`
// Initialize MCP client
const client = new MCP.Client();

// Connect to file system server
const connection = await client.connect(transport);

// Get resources
const resources = await connection.resources();
\`\`\`

## Example 2: Database Access

MCP can provide secure access to databases:

\`\`\`
// Read database schema
const schemaResource = await connection.readResource('db/schema');

// Execute a query
const result = await connection.callTool('query', {
  sql: 'SELECT * FROM users LIMIT 10'
});
\`\`\`
`
    );

    console.error('Resources initialized');
  }

  // Handle MCP requests
  async handleRequest(request) {
    const { id, method, params } = request;
    
    console.log("Handling method:", method);
    
    try {
      // Handle resources/list separately to avoid any issues with the switch statement
      if (method === 'resources/list') {
        console.log("Handling resources/list directly");
        return this.createResponse(id, this.resources);
      }
      
      switch (method) {
        case 'initialize':
          return this.createResponse(id, {
            name: 'MCP Demo Server',
            version: '1.0.0',
            capabilities: {
              resources: {
                supportedContentTypes: ['text/markdown']
              }
            }
          });
        
        case 'resources':
          console.log("Handling resources method");
          return this.createResponse(id, this.resources);
        
        case 'readResource':
          if (!params || !params.uri) {
            throw new Error('URI is required');
          }
          
          const content = await this.readResourceContent(params.uri);
          return this.createResponse(id, [{ 
            type: 'text', 
            text: content 
          }]);
        
        default:
          throw new Error(`Unsupported method: ${method}`);
      }
    } catch (error) {
      return this.createErrorResponse(id, error.message);
    }
  }

  // Read the content of a resource
  async readResourceContent(uri) {
    const resourcePath = path.join(__dirname, uri);
    
    try {
      return fs.readFileSync(resourcePath, 'utf8');
    } catch (error) {
      throw new Error(`Failed to read resource: ${error.message}`);
    }
  }

  // Create a standard JSON-RPC response
  createResponse(id, result) {
    return {
      jsonrpc: '2.0',
      id,
      result
    };
  }

  // Create an error response
  createErrorResponse(id, message, code = -32000) {
    return {
      jsonrpc: '2.0',
      id,
      error: {
        code,
        message
      }
    };
  }
}

// Create an HTTP server to handle MCP requests
const server = new MCPServer();

// Create an HTTP server to handle connections
const httpServer = http.createServer(async (req, res) => {
  if (req.method === 'POST') {
    let body = '';
    
    req.on('data', chunk => {
      body += chunk.toString();
    });
    
    req.on('end', async () => {
      try {
        const request = JSON.parse(body);
        console.log('Received request:', request);
        
        const response = await server.handleRequest(request);
        console.log('Sending response:', response);
        
        res.setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify(response));
      } catch (error) {
        console.error('Error processing request:', error);
        
        res.setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify({
          jsonrpc: '2.0',
          error: {
            code: -32700,
            message: 'Parse error'
          },
          id: null
        }));
      }
    });
  } else {
    // Handle CORS preflight requests
    if (req.method === 'OPTIONS') {
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
      res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
      res.statusCode = 204; // No content
      res.end();
      return;
    }
    
    // For any other method, return an error
    res.statusCode = 405; // Method not allowed
    res.end('Only POST requests are accepted');
  }
});

// Start the HTTP server
httpServer.listen(PORT, () => {
  console.log(`Documentation MCP Server running at http://localhost:${PORT}/`);
  console.log('Press Ctrl+C to stop the server.');
});

// Handle termination signals
process.on('SIGINT', () => {
  console.log('Received SIGINT, shutting down');
  httpServer.close(() => {
    console.log('HTTP server closed');
    process.exit(0);
  });
});

process.on('SIGTERM', () => {
  console.log('Received SIGTERM, shutting down');
  httpServer.close(() => {
    console.log('HTTP server closed');
    process.exit(0);
  });
});

// Process each line of input as a JSON-RPC request (for CLI usage)
rl.on('line', async (line) => {
  try {
    const request = JSON.parse(line);
    const response = await server.handleRequest(request);
    
    // Send the response
    process.stdout.write(JSON.stringify(response) + '\n');
  } catch (error) {
    console.error(`Error processing request: ${error.message}`);
    
    // Send an error response if we have a request id
    if (line && typeof line === 'string') {
      try {
        const { id } = JSON.parse(line);
        if (id) {
          const errorResponse = {
            jsonrpc: '2.0',
            id,
            error: {
              code: -32700,
              message: `Parse error: ${error.message}`
            }
          };
          process.stdout.write(JSON.stringify(errorResponse) + '\n');
        }
      } catch (e) {
        // If we can't parse the original request, just log the error
        console.error(`Failed to create error response: ${e.message}`);
      }
    }
  }
});

// Log any errors
rl.on('error', (error) => {
  console.error(`Input stream error: ${error.message}`);
}); 