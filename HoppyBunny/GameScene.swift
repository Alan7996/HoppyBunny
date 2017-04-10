//
//  GameScene.swift
//  HoppyBunny
//
//  Created by 수현 on 3/3/17.
//  Copyright © 2017 AlanLee. All rights reserved.
//

import SpriteKit

enum GameSceneState {
    case Active, GameOver
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    var hero: SKSpriteNode!
    var scrollLayer: SKNode!
    var obstacleLayer: SKNode!
    var scoreLabel: SKLabelNode!
    
    /* UI Connections */
    var buttonRestart: MSButtonNode!
    
    var sinceTouch : CFTimeInterval = 0
    let fixedDelta: CFTimeInterval = 1.0/60.0 /* 60 FPS */
    let scrollSpeed: CGFloat = 200
    var spawnTimer: CFTimeInterval = 0
    var points = 0
    
    /* Game management */
    var gameState: GameSceneState = .Active
    
    override func didMove(to view: SKView) {
        /* Set up your scene here */
        
        /* Recursive node search for 'hero' (child of referenced node) */
        hero = self.childNode(withName: "//hero") as! SKSpriteNode
        
        /* Set reference to scroll layer node */
        scrollLayer = self.childNode(withName: "scrollLayer")
        
        /* Set reference to obstacle layer node */
        obstacleLayer = self.childNode(withName: "obstacleLayer")
        
        /* Set physics contact delegate */
        physicsWorld.contactDelegate = self
        
        /* Set UI connections */
        buttonRestart = self.childNode(withName: "buttonRestart") as! MSButtonNode
        scoreLabel = self.childNode(withName: "scoreLabel") as! SKLabelNode
        
        /* Setup restart button selection handler */
        buttonRestart.selectedHandler = {
            /* Grab reference to our SpriteKit view */
            let skView = self.view as SKView!
            
            /* Load Game scene */
            let scene = GameScene(fileNamed:"GameScene") as GameScene!
            
            /* Ensure correct aspect mode */
            scene!.scaleMode = .aspectFill
            
            /* Restart game scene */
            skView!.presentScene(scene)
        }
        
        /* Hide restart button */
        buttonRestart.state = .Hidden
        
        /* Reset Score Label */
        scoreLabel.text = String(points)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        /* Called when a touch begins */
        
        /* Disable touch if game state is not acive */
        if gameState != .Active { return }
        
        /* Reset velocity, helps improve response against cumulative falling velocity */
        hero.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
        
        /* Apply vertical impulse */
        hero.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 25))
        
        /* Apply subtle rotation */
        hero.physicsBody?.applyAngularImpulse(1)
        
        /* Reset touch timer */
        sinceTouch = 0
        
        /* Play SFX */
        let flapSFX = SKAction.playSoundFileNamed("sfx_flap", waitForCompletion: false)
        self.run(flapSFX)
    }
    
    override func update(_ currentTime: CFTimeInterval) {
        /* Skip game update if game no longer active */
        if gameState != .Active { return }
        
        /* Called before each frame is rendered */
        
        /* Grab current velocity */
        let velocityY = hero.physicsBody?.velocity.dy ?? 0
        
        /* Check and cap vertical velocity */
        if velocityY > 400 {
            hero.physicsBody?.velocity.dy = 400
        }
        
        /* Apply falling rotation */
        if sinceTouch > 0.1 {
            let impulse = -20000 * fixedDelta
            hero.physicsBody?.applyAngularImpulse(CGFloat(impulse))
        }
        
        /* Clamp rotation */
        hero.zRotation.clamp(v1: CGFloat(-20).degreesToRadians(),CGFloat(30).degreesToRadians())
        hero.physicsBody?.angularVelocity.clamp(v1: -2, 2)
        
        /* Update last touch timer */
        sinceTouch+=fixedDelta
        
        /* Process world scrolling */
        scrollWorld()
        
        /* Process obstacles */
        updateObstacles()
        
        spawnTimer += fixedDelta
    }
    
    func scrollWorld() {
        /* Scroll World */
        scrollLayer.position.x -= scrollSpeed * CGFloat(fixedDelta)
        
        /* Loop through scroll layer nodes */
        for ground in scrollLayer.children as! [SKSpriteNode] {
            
            /* Get ground node position, convert node position to scene space */
            let groundPosition = scrollLayer.convert(ground.position, to: self)
            
            /* Check if ground sprite has left the scene */
            if groundPosition.x <= -ground.size.width {
                
                /* Reposition ground sprite to the second starting position */
                let newPosition = CGPoint(x: ground.size.width - 2,y: groundPosition.y)
                
                /* Convert new node position back to scroll layer space */
                ground.position = self.convert(newPosition, to: scrollLayer)
            }
        }
    }
    
    func updateObstacles() {
        /* Update Obstacles */
        
        obstacleLayer.position.x -= scrollSpeed * CGFloat(fixedDelta)
        
        /* Loop through obstacle layer nodes */
        for obstacle in obstacleLayer.children as! [SKReferenceNode] {
            
            /* Get obstacle node position, convert node position to scene space */
            let obstaclePosition = obstacleLayer.convert(obstacle.position, to: self)
            
            /* Check if obstacle has left the scene */
            if obstaclePosition.x <= -UIScreen.main.bounds.width / 2 {
                
                /* Remove obstacle node from obstacle layer */
                obstacle.removeFromParent()
            }
            
        }
        
        /* Time to add a new obstacle? */
        if spawnTimer >= 1.5 {
            
            /* Create a new obstacle reference object using our obstacle resource */
            let resourcePath = Bundle.main.path(forResource: "Obstacle", ofType: "sks")
            let newObstacle = SKReferenceNode (url: NSURL (fileURLWithPath: resourcePath!) as URL)
            obstacleLayer.addChild(newObstacle)
            
            /* Generate new obstacle position, start just outside screen and with a random y value */
            let randomPosition = CGPoint(x: UIScreen.main.bounds.width / 2, y: CGFloat.random(min: 0, max: 150))
            
            /* Convert new node position back to obstacle layer space */
            newObstacle.position = self.convert(randomPosition, to: obstacleLayer)
            
            // Reset spawn timer
            spawnTimer = 0
        }
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        /* Ensures only called while game running */
        if gameState != .Active { return }
        
        /* Hero touches anything, game over */
        
        /* Get reference to bodies involved in collision */
        let contactA:SKPhysicsBody = contact.bodyA
        let contactB:SKPhysicsBody = contact.bodyB
        
        /* Get reference to the physics body parent nodes */
        let nodeA = contactA.node!
        let nodeB = contactB.node!
        
        /* Did our hero pass through the 'goal'? */
        if nodeA.name == "goal" || nodeB.name == "goal" {
            /* Increment points */
            points += 1
            
            /* Update score label */
            scoreLabel.text = String(points)
            
            return
        }
        
        /* Change game state to game over */
        gameState = .GameOver
        
        /* Stop any new angular velocity being applied */
        hero.physicsBody?.allowsRotation = false
        
        /* Reset angular velocity */
        hero.physicsBody?.angularVelocity = 0
        
        /* Stop hero flapping animation */
        hero.removeAllActions()
        
        /* Create our hero death action */
        let heroDeath = SKAction.run({
            /* Put our hero face down in the dirt */
            self.hero.zRotation = CGFloat(-90).degreesToRadians()
            
            /* Stop hero from colliding with anything else */
            self.hero.physicsBody?.collisionBitMask = 0
            
            self.hero.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
            
            self.hero.physicsBody?.affectedByGravity = false
        })
        
        /* Run action */
        hero.run(heroDeath)
        
        /* Load the shake action resource */
        let shakeScene:SKAction = SKAction.init(named: "Shake")!
        
        /* Loop through all nodes */
        for node in self.children {
            /* Apply effect each ground node */
            node.run(shakeScene)
        }
        
        /* Show restart button */
        buttonRestart.state = .Active
    }
}
