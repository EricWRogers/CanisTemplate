#include <Game.hpp>

#include <Canis/App.hpp>
#include <Canis/Debug.hpp>

#include <GameData.hpp>
#include <RegisterScripts.generated.hpp>

extern "C"
{
    void* GameInit(void* _app)
    {
        Canis::App& app = *static_cast<Canis::App*>(_app);
        RegisterGeneratedScripts(app);

        Canis::Debug::Log("Game initialized.");
        return new GameData{};
    }

    void GameUpdate(void* _app, float _deltaTime, void* _data)
    {
        (void)_app;
        (void)_deltaTime;

        GameData& gameData = *static_cast<GameData*>(_data);
        gameData.frameCount++;
    }

    void GameShutdown(void* _app, void* _data)
    {
        Canis::App& app = *static_cast<Canis::App*>(_app);
        UnRegisterGeneratedScripts(app);

        Canis::Debug::Log("Game shutdown.");
        delete static_cast<GameData*>(_data);
    }
}
