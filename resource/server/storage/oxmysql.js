'use strict';
// Adapter for the pinned oxmysql 2.14.3 interactive transaction export.
// No retry/fallback: callers reconcile unknown outcomes through persisted revision.
function createOxPool(api,dispatch=fn=>fn()) {
  let stopped=false;
  const active=new Set();
  const call=fn=>new Promise((resolve,reject)=>dispatch(()=>{try{Promise.resolve(fn()).then(resolve,reject);}catch(e){reject(e);}}));
  return {
    async getConnection(){
      if(stopped)throw new Error('Storage stopped');
      if(api.isReady && !await call(()=>api.isReady()))throw new Error('Database pool is not ready');
      let run=null,finish=null,completion=null,released=false;
      const connection={
        async query(sql,args=[]){if(released||stopped)throw new Error('Connection closed');return [await call(()=>run?run(sql,args):api.query_async(sql,args))];},
        async beginTransaction(){
          if(completion)throw new Error('Transaction already started');
          let ready,notReady;
          const started=new Promise((resolve,reject)=>{ready=resolve;notReady=reject;});
          const decision=new Promise(resolve=>{finish=resolve;});
          completion=call(()=>api.startTransaction(async query=>{run=query;ready();return decision;}));
          completion.then(()=>notReady(new Error('Transaction did not start')),()=>notReady(new Error('Transaction unavailable')));
          await started;
        },
        async commit(){
          if(!completion)return;
          finish(true);const result=await completion;run=null;
          if(result!==true)throw new Error('Transaction outcome unavailable');
        },
        async rollback(){if(completion){finish(false);await completion;run=null;}},
        release(){if(released)return completion;released=true;active.delete(connection);if(finish)finish(false);return completion;}
      };
      active.add(connection);return connection;
    },
    async end(){stopped=true;await Promise.allSettled([...active].map(connection=>connection.release()));}
  };
}
function oxConnectionString(config){
  const result=[];
  for(const key of ['host','port','user','password','database']){
    const value=String(config[key]??'');
    if(/[;=\r\n\0]/.test(value))throw new Error('Unsupported character in oxmysql configuration');
    result.push(key+'='+value);
  }
  result.push('charset=utf8mb4','connectTimeout=10000','connectionLimit=4','supportBigNumbers=true','bigNumberStrings=true');
  if(config.ssl)result.push('ssl='+JSON.stringify(config.ssl).replace(/=/g,'\\u003d').replace(/;/g,'\\u003b'));
  const value=result.join(';');
  if(value.includes('mysql://'))throw new Error('Unsupported oxmysql URI marker in configuration');
  return value;
}
module.exports={createOxPool,oxConnectionString};
