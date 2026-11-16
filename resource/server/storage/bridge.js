'use strict';
const L=require('./locale_en');
// Local server export only. No HTTP listener or client network event is exposed.
function createBridge(store, initializeOptions={}) {
  let initialized = false, initializing = null, stopped = false;
  async function ready() {
    if (stopped) throw new Error('Storage stopped');
    if (!initialized) {
      if (!initializing) initializing = Promise.resolve().then(() => store.initialize(initializeOptions)).then(() => {initialized=true;}).finally(() => {initializing=null;});
      await initializing;
    }
  }
  async function request(route, method='GET', body='') {
    try {
      if (typeof body !== 'string' || Buffer.byteLength(body)>4500000) return {code:413,data:{error:L.body}};
      const payload = body ? JSON.parse(body) : {};
      if (!payload || typeof payload !== 'object' || Array.isArray(payload)) return {code:400,data:{error:L.request}};
      if (!((route==='/state' && method==='GET') || (route==='/commit' && method==='POST') || (route==='/wipe' && method==='POST'))) {
        return {code:404,data:{error:L.operation}};
      }
      await ready();
      let data;
      if (route==='/state') data=await store.state();
      else if (route==='/commit') data=await store.commit(payload.revision,payload.state,payload.audit ?? {});
      else data=await store.wipe(payload.key,payload.dryRun ?? false);
      return {code:200,data};
    } catch (error) {
      if (error?.code==='CONFLICT') return {code:409,data:{error:L.conflict}};
      if (error?.code==='BACKUP_UNAVAILABLE') return {code:503,data:{error:L.backup}};
      if (error?.code==='VALIDATION' || error instanceof SyntaxError) return {code:400,data:{error:L.invalid}};
      // A failure may occur after commit; the caller must reconcile before retry.
      return {code:503,data:{error:L.unavailable}};
    }
  }
  return {request, ready, stop:async()=>{stopped=true;await store.close();}};
}
module.exports = {createBridge};
