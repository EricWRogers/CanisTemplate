Module = typeof Module !== 'undefined' ? Module : {};
Module.preRun = Module.preRun || [];
Module.preRun.push(function () {
  try {
    FS.mkdir('/persistent');
  } catch (error) {
    if (!FS.analyzePath('/persistent').exists) {
      throw error;
    }
  }
  FS.mount(IDBFS, {}, '/persistent');
  addRunDependency('canis-persistent-sync');
  FS.syncfs(true, function (error) {
    if (error) {
      console.error('Canis persistent storage restore failed', error);
    }
    removeRunDependency('canis-persistent-sync');
  });
});
