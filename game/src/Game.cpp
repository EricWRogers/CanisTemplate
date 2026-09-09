#include <Game.hpp>
#include <InputActions.generated.hpp>
#include <Canis/Canis.hpp>
#include <Canis/InputManager.hpp>

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
        auto& input = app.scene.GetInputManager();
        std::string inputError;
        if (!input.Actions().RegisterSchema(GeneratedInput::Schema(), inputError) ||
            !input.Actions().Load(Canis::GetProjectConfig().inputAsset, inputError))
            Canis::Debug::Error("Input initialization failed: %s", inputError.c_str());
        if (!input.Actions().LoadOverrides(Canis::InputUserOverridesPath(), inputError))
            Canis::Debug::Warning("Input overrides reset: %s", inputError.c_str());
        input.Actions().SetGlyphCatalog("assets/textures/input/glyphs.canis");
        input.EnableMap(InputMap::Gameplay);

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
        app.scene.GetInputManager().Actions().UnregisterSchema();
        UnRegisterGeneratedScripts(app);

        Canis::Debug::Log("Game shutdown.");
        delete static_cast<GameData*>(_data);
    }
}
