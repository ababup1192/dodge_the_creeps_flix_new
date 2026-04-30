def main(): Unit \ IO =
    if (GameEngine.ensureMainThread()) ()
    else {
        let config: GameEngine.EngineConfig = {
            screenWidth = Game.screenWi(),
            screenHeight = Game.screenHi(),
            title = "Dodge the Creeps!",
            textureManifest =
                {name = "playerGrey_walk1", path = "textures/playerGrey_walk1.png", hasAlpha = true} ::
                {name = "playerGrey_walk2", path = "textures/playerGrey_walk2.png", hasAlpha = true} ::
                {name = "playerGrey_up1", path = "textures/playerGrey_up1.png", hasAlpha = true} ::
                {name = "playerGrey_up2", path = "textures/playerGrey_up2.png", hasAlpha = true} ::
                {name = "enemyWalking_1", path = "textures/enemyWalking_1.png", hasAlpha = true} ::
                {name = "enemyWalking_2", path = "textures/enemyWalking_2.png", hasAlpha = true} ::
                {name = "enemyFlyingAlt_1", path = "textures/enemyFlyingAlt_1.png", hasAlpha = true} ::
                {name = "enemyFlyingAlt_2", path = "textures/enemyFlyingAlt_2.png", hasAlpha = true} ::
                {name = "enemySwimming_1", path = "textures/enemySwimming_1.png", hasAlpha = true} ::
                {name = "enemySwimming_2", path = "textures/enemySwimming_2.png", hasAlpha = true} ::
                Nil,
            fontManifest =
                {name = "default", path = "textures/Xolonium-Regular.ttf", fontSize = 32.0} ::
                Nil,
            clearColor = {r = 0.3f32, g = 0.3f32, b = 0.3f32}
        };
       
        run {
            Game.start(GameEngine.Game.getFontAtlas("default"))
        } with LwjglLayer.withLwjgl(config)
    }
