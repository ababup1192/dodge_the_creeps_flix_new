def main(): Unit \ IO =
    if (Engine.ensureMainThread()) ()
    else {
        let config: Engine.EngineConfig = {
            screenWidth = Game.screenWi(),
            screenHeight = Game.screenHi(),
            title = "Dodge the Creeps!",
            textureManifest =
                {name = "playerGrey_walk1", path = "textures/playerGrey_walk1.png", hasAlpha = true} ::
                {name = "playerGrey_walk2", path = "textures/playerGrey_walk2.png", hasAlpha = true} ::
                {name = "playerGrey_up1", path = "textures/playerGrey_up1.png", hasAlpha = true} ::
                {name = "playerGrey_up2", path = "textures/playerGrey_up2.png", hasAlpha = true} ::
                Nil,
            fontManifest =
                {name = "default", path = "textures/Xolonium-Regular.ttf", fontSize = 32.0} ::
                Nil,
            clearColor = {r = 0.3f32, g = 0.3f32, b = 0.3f32}
        };
        run {
            Game.start(Engine.Game.getFontAtlas("default"))
        } with LwjglLayer.withLwjgl(config)
    }
