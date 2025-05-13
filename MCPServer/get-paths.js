#!/usr/bin/env node

const path = require('path');

// Get the full paths of the MCP servers
const serverPath = path.resolve(__dirname, 'server.js');
const databaseServerPath = path.resolve(__dirname, 'database-server.js');

console.log('\n=== MCP Server Paths ===\n');
console.log('Documentation Server:');
console.log(serverPath);
console.log('\nDatabase Server:');
console.log(databaseServerPath);
console.log('\n=======================\n');
console.log('Use these paths when connecting to the servers in the MCPDemo Mac app.');
console.log('For example, in the MCP Connector dialog:');
console.log('- Server Name: MCP Documentation');
console.log(`- Executable Path: ${serverPath}`);
console.log('- Arguments: [leave empty]\n'); 