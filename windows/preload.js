'use strict'

const { contextBridge, ipcRenderer } = require('electron')

const subscribe = channel => callback => {
  const listener = (_event, payload) => callback(payload)
  ipcRenderer.on(channel, listener)
  return () => ipcRenderer.removeListener(channel, listener)
}

contextBridge.exposeInMainWorld('toolbox', {
  getState: () => ipcRenderer.invoke('app:state'),
  onStateChanged: subscribe('state:changed'),
  onCounterTick: subscribe('counter:tick'),

  water: {
    add: ml => ipcRenderer.invoke('water:add', ml),
    undo: () => ipcRenderer.invoke('water:undo'),
    reset: () => ipcRenderer.invoke('water:reset'),
    setSizes: sizes => ipcRenderer.invoke('water:set-sizes', sizes),
  },

  counter: {
    increment: () => ipcRenderer.invoke('counter:increment'),
    decrement: () => ipcRenderer.invoke('counter:decrement'),
    reset: () => ipcRenderer.invoke('counter:reset'),
    undo: () => ipcRenderer.invoke('counter:undo'),
    setRate: rate => ipcRenderer.invoke('counter:set-rate', rate),
    toggleAuto: () => ipcRenderer.invoke('counter:toggle-auto'),
    save: name => ipcRenderer.invoke('counter:save', name),
    load: id => ipcRenderer.invoke('counter:load', id),
    remove: id => ipcRenderer.invoke('counter:delete', id),
  },

  sync: {
    setEnabled: enabled => ipcRenderer.invoke('sync:set-enabled', enabled),
    setName: name => ipcRenderer.invoke('sync:set-name', name),
    syncNow: () => ipcRenderer.invoke('sync:sync-now'),
  },

  update: {
    getState: () => ipcRenderer.invoke('update:state'),
    check: () => ipcRenderer.invoke('update:check'),
    install: () => ipcRenderer.invoke('update:install'),
    setAutomatic: enabled => ipcRenderer.invoke('update:set-automatic', enabled),
    onChanged: subscribe('update:changed'),
  },
})
