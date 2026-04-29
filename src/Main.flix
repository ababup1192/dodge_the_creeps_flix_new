def main(): Unit \ IO =
    if (Engine.ensureMainThread()) ()
    else {
        let config: Engine.EngineConfig = {
            screenWidth = Game.screenWi(),
            screenHeight = Game.screenHi(),
            title = "Frogger",
            textureManifest =
                {name = "white", path = "textures/white_1x1.png", hasAlpha = true} ::
                {name = "FroggerIdle", path = "textures/FroggerIdle.png", hasAlpha = true} ::
                {name = "FroggerLeap", path = "textures/FroggerLeap.png", hasAlpha = true} ::
                {name = "FroggerDead", path = "textures/FroggerDead.png", hasAlpha = true} ::
                {name = "Water", path = "textures/Water.png", hasAlpha = true} ::
                {name = "Road", path = "textures/Road.png", hasAlpha = true} ::
                {name = "Median", path = "textures/Median.png", hasAlpha = true} ::
                {name = "Car1", path = "textures/Car1.png", hasAlpha = true} ::
                {name = "Car2", path = "textures/Car2.png", hasAlpha = true} ::
                {name = "Car3", path = "textures/Car3.png", hasAlpha = true} ::
                {name = "Car4", path = "textures/Car4.png", hasAlpha = true} ::
                {name = "Car5", path = "textures/Car5.png", hasAlpha = true} ::
                {name = "LogStart", path = "textures/LogStart.png", hasAlpha = true} ::
                {name = "LogMiddle", path = "textures/LogMiddle.png", hasAlpha = true} ::
                {name = "LogEnd", path = "textures/LogEnd.png", hasAlpha = true} ::
                {name = "Turtle_01", path = "textures/Turtle_01.png", hasAlpha = true} ::
                {name = "Turtle_02", path = "textures/Turtle_02.png", hasAlpha = true} ::
                {name = "Turtle_03", path = "textures/Turtle_03.png", hasAlpha = true} ::
                {name = "Home", path = "textures/Home.png", hasAlpha = true} ::
                {name = "HomeFrog", path = "textures/HomeFrog.png", hasAlpha = true} ::
                Nil,
            fontManifest =
                {name = "default", path = "textures/Xolonium-Regular.ttf", fontSize = 32.0f32} ::
                Nil,
            clearColor = {r = 0.1f32, g = 0.1f32, b = 0.1f32}
        };
        LwjglLayer.withLwjgl(config, () -> {
            let fontAtlas = Engine.Game.getFontAtlas("default");
            Game.start(fontAtlas)
        })
    }
