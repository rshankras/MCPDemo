#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const readline = require('readline');
const SQLite = require('better-sqlite3');
const http = require('http');

// Port for HTTP server
const PORT = 3001;

// Set up the input/output streams for the Model Context Protocol
const rl = readline.createInterface({
  input: process.stdin,
  output: null,
  terminal: false
});

// Simple MCP Database Server implementation
class MCPDatabaseServer {
  constructor() {
    this.resources = [
      {
        uri: 'database/schema.md',
        type: 'markdown',
        name: 'Database Schema',
        description: 'Database schema documentation'
      },
      {
        uri: 'database/sample.md',
        type: 'markdown',
        name: 'Sample Data',
        description: 'Sample data in the database'
      }
    ];
    
    // Create the database and resources
    this.initializeDatabase();
    this.initializeResources();
  }

  // Initialize SQLite database
  initializeDatabase() {
    const dbDir = path.join(__dirname, 'database');
    
    if (!fs.existsSync(dbDir)) {
      fs.mkdirSync(dbDir, { recursive: true });
    }

    const dbPath = path.join(dbDir, 'demo.db');
    this.db = new SQLite(dbPath);
    
    // Create tables
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS employees (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        title TEXT NOT NULL,
        department TEXT NOT NULL,
        salary REAL,
        hire_date TEXT,
        email TEXT
      );
    `);
    
    // Check if we need to insert sample data
    const count = this.db.prepare('SELECT COUNT(*) as count FROM employees').get();
    
    if (count.count === 0) {
      // Insert sample data
      const insert = this.db.prepare(`
        INSERT INTO employees (name, title, department, salary, hire_date, email)
        VALUES (?, ?, ?, ?, ?, ?)
      `);
      
      const sampleEmployees = [
        ['John Smith', 'Senior Developer', 'Engineering', 120000, '2020-03-15', 'john.smith@example.com'],
        ['Jane Doe', 'Product Manager', 'Product', 115000, '2019-06-22', 'jane.doe@example.com'],
        ['Michael Johnson', 'UX Designer', 'Design', 95000, '2021-01-10', 'michael.j@example.com'],
        ['Emily Brown', 'Marketing Specialist', 'Marketing', 85000, '2022-04-05', 'emily.b@example.com'],
        ['David Lee', 'Data Scientist', 'Data', 125000, '2020-11-30', 'david.lee@example.com'],
        ['Sarah Wilson', 'HR Manager', 'Human Resources', 105000, '2018-08-12', 'sarah.w@example.com'],
        ['Robert Miller', 'Financial Analyst', 'Finance', 90000, '2021-09-18', 'robert.m@example.com'],
        ['Jennifer Garcia', 'Customer Support', 'Support', 75000, '2022-02-28', 'jennifer.g@example.com'],
        ['Thomas Anderson', 'DevOps Engineer', 'Engineering', 115000, '2019-12-01', 'thomas.a@example.com'],
        ['Lisa Martinez', 'Content Writer', 'Marketing', 80000, '2021-05-15', 'lisa.m@example.com']
      ];
      
      sampleEmployees.forEach(employee => {
        insert.run(...employee);
      });
    }
    
    console.error('Database initialized');
  }

  // Initialize the documentation resources (files) for this demo
  initializeResources() {
    const dbDir = path.join(__dirname, 'database');
    
    // Schema documentation
    fs.writeFileSync(
      path.join(dbDir, 'schema.md'),
      `# Database Schema

## Table: employees

| Column     | Type    | Description                     |
|------------|---------|---------------------------------|
| id         | INTEGER | Primary key                     |
| name       | TEXT    | Employee's full name            |
| title      | TEXT    | Job title                       |
| department | TEXT    | Department name                 |
| salary     | REAL    | Annual salary                   |
| hire_date  | TEXT    | Date hired (YYYY-MM-DD)         |
| email      | TEXT    | Employee's email address        |

`
    );

    // Sample data documentation
    fs.writeFileSync(
      path.join(dbDir, 'sample.md'),
      `# Sample Data

The database contains sample employee records for demonstration purposes.

## Example Queries

### Get all employees

\`\`\`sql
SELECT * FROM employees;
\`\`\`

### Get employees by department

\`\`\`sql
SELECT * FROM employees WHERE department = 'Engineering';
\`\`\`

### Get average salary by department

\`\`\`sql
SELECT department, AVG(salary) as avg_salary 
FROM employees 
GROUP BY department
ORDER BY avg_salary DESC;
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
            name: 'MCP Database Server',
            version: '1.0.0',
            capabilities: {
              resources: {
                supportedContentTypes: ['text/markdown']
              },
              tools: {
                supported: true
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

        case 'tools':
          return this.createResponse(id, [
            {
              name: 'executeQuery',
              description: 'Execute an SQL query on the database',
              parameters: {
                type: 'object',
                required: ['sql'],
                properties: {
                  sql: {
                    type: 'string',
                    description: 'SQL query to execute'
                  }
                }
              }
            }
          ]);
        
        case 'executeQuery':
          if (!params || !params.sql) {
            throw new Error('SQL query is required');
          }
          
          const results = await this.executeQuery(params.sql);
          return this.createResponse(id, {
            content: [{ 
              type: 'json', 
              json: results 
            }]
          });
        
        default:
          throw new Error(`Unsupported method: ${method}`);
      }
    } catch (error) {
      return this.createErrorResponse(id, error.message);
    }
  }

  // Execute an SQL query
  async executeQuery(sql) {
    try {
      // Basic SQL injection protection - block destructive commands
      const lowerSql = sql.toLowerCase();
      if (lowerSql.includes('drop table') || 
          lowerSql.includes('delete from') ||
          lowerSql.includes('update ')) {
        throw new Error('Destructive SQL commands are not allowed');
      }
      
      // For SELECT queries, return the results
      if (lowerSql.trim().startsWith('select')) {
        const stmt = this.db.prepare(sql);
        const rows = stmt.all();
        return rows;
      } else {
        throw new Error('Only SELECT queries are allowed');
      }
    } catch (error) {
      throw new Error(`Query execution failed: ${error.message}`);
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
const server = new MCPDatabaseServer();

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
  console.log(`Database MCP Server running at http://localhost:${PORT}/`);
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