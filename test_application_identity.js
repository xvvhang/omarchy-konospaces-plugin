const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const resolver = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, 'ApplicationIdentity.js'), 'utf8'), resolver);
const entries = [
  {id: 'foot', name: 'Foot', icon: 'foot', command: ['foot']},
  {id: 'foot-server', name: 'Foot Server', command: ['foot', '--server']},
  {id: 'nvim', name: 'Neovim', icon: 'nvim', command: ['nvim', '%F']},
  {id: 'htop', name: 'Htop', command: ['/usr/bin/htop']},
  {id: 'editor.desktop', name: 'Editor', startupClass: 'EditorClass', command: ['editor']},
  {id: 'chat-web', name: 'Chat Web', execString: 'omarchy-launch-webapp "https://chat.example.com"'}
];
function resolve(appId, extra = {}, processes = {}) {
  return resolver.resolve({appId, ...extra}, entries, processes);
}

assert.equal(resolve('foot').source, 'desktop-entry');
assert.equal(resolve('foot').name, 'Foot');
assert.equal(resolve('editor').name, 'Editor');
assert.equal(resolve('EditorClass').name, 'Editor');
assert.equal(resolve('org.omarchy.nvim', {pid: 42}, {'42': 'foot'}).name, 'Neovim');
assert.equal(resolve('org.omarchy.nvim').icon, 'nvim');
assert.equal(resolve('org.omarchy.nvim').source, 'omarchy-launcher');
assert.equal(resolve('org.omarchy.htop').name, 'Htop');
assert.equal(resolve('org.omarchy.unknown').source, 'unresolved');
assert.equal(resolve('org.omarchy.unknown').name, 'org.omarchy.unknown');
assert.equal(resolve('TUI.float', {pid: 42}, {'42': 'foot'}).source, 'process');
assert.equal(resolve('TUI.float').name, 'TUI.float');
assert.equal(resolve('', {className: 'foot'}).name, 'Foot');
assert.equal(resolve('unknown', {title: 'Neovim', initialTitle: 'Neovim'}).name, 'unknown');
assert.equal(resolve('', {title: 'Neovim'}).name, 'Window');
assert.equal(resolve('chrome-chat.example.com__-Default').name, 'Chat Web');

const duplicates = entries.concat({id: 'other-editor', name: 'Other', startupClass: 'EditorClass'});
assert.equal(resolver.resolve({appId: 'EditorClass'}, duplicates, {}).source, 'unresolved');
const sameCommand = entries.concat({id: 'other-htop', command: ['htop']});
// An exact desktop ID still wins; only command-name inference is ambiguous.
assert.equal(resolver.resolve({appId: 'org.omarchy.htop'}, sameCommand, {}).name, 'Htop');
const commands = [{id: 'one', command: ['tool']}, {id: 'two', command: ['/usr/bin/tool']}];
assert.equal(resolver.resolve({appId: 'org.omarchy.tool'}, commands, {}).source, 'unresolved');
const duplicateWeb = entries.concat({id: 'chat2', execString: 'browser https://chat.example.com'});
assert.equal(resolver.resolve({appId: 'chrome-chat.example.com__-Default'}, duplicateWeb, {}).source, 'unresolved');
assert.equal(resolver.resolve({appId: 'org.omarchy.terminal'}, entries, {}, 'foot.desktop').name, 'Foot');
assert.equal(resolver.resolve({appId: 'org.omarchy.terminal'}, entries, {}, 'foot.desktop').source, 'default-terminal');
assert.equal(resolver.resolve({appId: 'org.omarchy.nvim'}, entries, {}, 'foot.desktop').name, 'Neovim');
assert.equal(resolver.resolve({appId: 'org.omarchy.unknown'}, entries, {}, 'foot.desktop').source, 'unresolved');
assert.equal(resolve('org.omarchy.nvim', {initialClass: 'foot'}).name, 'Neovim');
const postman = [{id: 'postman', name: 'Postman', icon: 'postman', startupClass: 'postman'}];
assert.equal(resolver.resolve({appId: 'Postman'}, postman, {}).icon, 'postman');
assert.equal(resolver.resolve({appId: 'Postman'}, postman, {}).source, 'desktop-entry-relaxed');
assert.equal(resolver.resolve({appId: 'POSTMAN.desktop'}, postman, {}).entryId, 'postman');
assert.equal(resolver.resolve({appId: 'editorclass'}, entries, {}).entryId, 'editor.desktop');
assert.equal(resolver.resolve({appId: 'Postman', initialClass: 'foot'}, entries.concat(postman), {}).entryId, 'foot');
const caseCollision = postman.concat({id: 'POSTMAN', name: 'Other'});
assert.equal(resolver.resolve({appId: 'Postman'}, caseCollision, {}).source, 'unresolved');
assert.equal(resolver.resolve({appId: 'POSTMAN'}, caseCollision, {}).entryId, 'POSTMAN');
const classCollision = postman.concat({id: 'other', startupClass: 'POSTMAN'});
assert.equal(resolver.resolve({appId: 'Postman'}, classCollision, {}).source, 'unresolved');
assert.equal(resolver.resolve({appId: 'Postman', initialClass: 'FOOT'}, entries.concat(postman), {}).source, 'unresolved');
assert.equal(resolver.resolve({appId: 'Postman'}, postman, {'42': 'foot'}).entryId, 'postman');
assert.equal(resolver.resolve({appId: 'Post'}, postman, {}).source, 'unresolved');
console.log('Application identity tests passed');
