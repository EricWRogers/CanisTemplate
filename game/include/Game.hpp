#pragma once

extern "C"
{
    void* GameInit(void* _app);
    void GameUpdate(void* _app, float _deltaTime, void* _data);
    void GameShutdown(void* _app, void* _data);
}
