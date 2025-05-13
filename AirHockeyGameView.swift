//
//  AirHockeyGameView.swift
//  GPSCamera
//
//  Created by HKinfoway Tech. on 13/05/25.
//


import SwiftUI

#Preview {
    AirHockeyGameView()
}


struct AirHockeyGameView: View {
    @State private var previousDragPosition: CGPoint?
    @State private var malletVelocity = CGVector(dx: 0, dy: 0)
    @State private var puckPosition = CGPoint(x: 200, y: 400)
    @State private var puckVelocity = CGVector(dx: 4, dy: 4)
    @State private var previousMalletPosition = CGPoint(x: 200, y: 700)
    @State private var player1MalletPosition = CGPoint(x: 200, y: 700)
    @State private var player2MalletPosition = CGPoint(x: 200, y: 100)

    @State private var player1Score = 0
    @State private var player2Score = 0

    @State private var goalAnimation = false
    @State private var gradientOffset: CGFloat = -1.0

    @State private var showGoalCelebration = false
    @State private var goalTextPosition: CGPoint = .zero

    let puckRadius: CGFloat = 20
    let malletRadius: CGFloat = 35
    let goalWidth: CGFloat = 100
    let player2Speed: CGFloat = 4
    let speedFactor: CGFloat = 0.15 // <--- Controls how strong the puck is hit
    let timer = Timer.publish(every: 1 / 60, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                if goalAnimation {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .cyan.opacity(0.0),
                            .cyan.opacity(0.3),
                            .purple.opacity(0.4),
                            .blue.opacity(0.3),
                            .cyan.opacity(0.0)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .scaleEffect(1.5)
                    .opacity(0.7)
                    .blur(radius: 50)
                    .offset(x: geometry.size.width * gradientOffset, y: 0)
                    .animation(.easeInOut(duration: 1.2), value: gradientOffset)
                    .transition(.opacity)
                    .ignoresSafeArea()
                }

                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.cyan.opacity(goalAnimation ? 1 : 0.4), lineWidth: 6)
                    .shadow(color: .cyan.opacity(goalAnimation ? 0.8 : 0.3), radius: goalAnimation ? 20 : 5)
                    .padding(10)

                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(.white)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                Rectangle()
                    .frame(width: goalWidth, height: 5)
                    .foregroundColor(.green)
                    .position(x: geometry.size.width / 2, y: geometry.size.height - 10)

                Rectangle()
                    .frame(width: goalWidth, height: 5)
                    .foregroundColor(.green)
                    .position(x: geometry.size.width / 2, y: 10)

                VStack {
                    HStack {
                        Text("Player 1: \(player1Score)")
                        Spacer()
                        Text("Player 2: \(player2Score)")
                    }
                    .foregroundColor(.white)
                    .font(.title)
                    .padding()
                    Spacer()
                }

                // Puck
                Circle()
                    .fill(Color.white)
                    .frame(width: puckRadius * 2, height: puckRadius * 2)
                    .position(puckPosition)

                // Player 1 Mallet with Drag Velocity
                Circle()
                    .fill(Color.red)
                    .frame(width: malletRadius * 2, height: malletRadius * 2)
                    .position(player1MalletPosition)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let minY = geometry.size.height / 2 + malletRadius
                                let maxY = geometry.size.height - malletRadius
                                let x = min(max(value.location.x, malletRadius), geometry.size.width - malletRadius)
                                let y = min(max(value.location.y, minY), maxY)
                                let newPosition = CGPoint(x: x, y: y)

                                // Track drag velocity
                                if let previous = previousDragPosition {
                                    let dx = newPosition.x - previous.x
                                    let dy = newPosition.y - previous.y
                                    malletVelocity = CGVector(dx: dx, dy: dy)
                                }
                                previousDragPosition = newPosition
                                player1MalletPosition = newPosition
                            }
                            .onEnded { _ in
                                malletVelocity = .zero
                                previousDragPosition = nil
                            }
                    )


                // Player 2 Mallet (AI)
                Circle()
                    .fill(Color.green)
                    .frame(width: malletRadius * 2, height: malletRadius * 2)
                    .position(player2MalletPosition)

                // Celebration Text
                if showGoalCelebration {
                    Text("🏆 GOAL! 🏆")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.yellow)
                        .shadow(color: .orange, radius: 10)
                        .position(goalTextPosition)
                        .scaleEffect(1.2)
                        .transition(.scale)
                }
            }
            .onReceive(timer) { _ in
                guard !goalAnimation else { return }
                updatePuck(in: geometry.size)
                detectCollision(with: player1MalletPosition, malletVelocity: malletVelocity)
                detectCollision(with: player2MalletPosition)
                checkGoals(in: geometry.size)
                moveAI(in: geometry.size)
            }
        }
    }

    private func updatePuck(in size: CGSize) {
        puckPosition.x += puckVelocity.dx
        puckPosition.y += puckVelocity.dy

        if puckPosition.x <= puckRadius || puckPosition.x >= size.width - puckRadius {
            puckVelocity.dx *= -1
            puckPosition.x = max(puckRadius, min(size.width - puckRadius, puckPosition.x))
        }

        if puckPosition.y <= puckRadius || puckPosition.y >= size.height - puckRadius {
            puckVelocity.dy *= -1
            puckPosition.y = max(puckRadius, min(size.height - puckRadius, puckPosition.y))
        }
    }

    private func detectCollision(with malletPosition: CGPoint, malletVelocity: CGVector = .zero) {
        let dx = puckPosition.x - malletPosition.x
        let dy = puckPosition.y - malletPosition.y
        let distance = sqrt(dx * dx + dy * dy)
        let minDistance = puckRadius + malletRadius

        guard distance < minDistance, distance > 0 else { return }

        // Normal vector
        let normalX = dx / distance
        let normalY = dy / distance

        // Push puck outside the mallet
        let overlap = minDistance - distance
        puckPosition.x += normalX * overlap
        puckPosition.y += normalY * overlap

        // Reflect puck velocity
        let dotProduct = puckVelocity.dx * normalX + puckVelocity.dy * normalY
        puckVelocity.dx -= 2 * dotProduct * normalX
        puckVelocity.dy -= 2 * dotProduct * normalY

        // Add mallet push (even if small)
        puckVelocity.dx += malletVelocity.dx * 0.2
        puckVelocity.dy += malletVelocity.dy * 0.2
    }



    private func checkGoals(in size: CGSize) {
        if puckPosition.y <= puckRadius &&
            puckPosition.x > size.width / 2 - goalWidth / 2 &&
            puckPosition.x < size.width / 2 + goalWidth / 2 {
            player1Score += 1
            resetPuck(in: size)
            triggerGoalAnimation(at: CGPoint(x: size.width / 2, y: 80))
        }

        if puckPosition.y >= size.height - puckRadius &&
            puckPosition.x > size.width / 2 - goalWidth / 2 &&
            puckPosition.x < size.width / 2 + goalWidth / 2 {
            player2Score += 1
            resetPuck(in: size)
            triggerGoalAnimation(at: CGPoint(x: size.width / 2, y: size.height - 80))
        }
    }

    private func resetPuck(in size: CGSize) {
        puckPosition = CGPoint(x: size.width / 2, y: size.height / 2)
        puckVelocity = CGVector(dx: 4, dy: 4)
    }

    private func moveAI(in size: CGSize) {
        let targetX = puckPosition.x
        let currentX = player2MalletPosition.x

        if targetX > currentX + malletRadius {
            player2MalletPosition.x = min(currentX + player2Speed, size.width - malletRadius)
        } else if targetX < currentX - malletRadius {
            player2MalletPosition.x = max(currentX - player2Speed, malletRadius)
        }
    }

    private func triggerGoalAnimation(at position: CGPoint) {
        goalAnimation = true
        showGoalCelebration = true
        goalTextPosition = position
        gradientOffset = -1.0

        withAnimation(Animation.easeInOut(duration: 1.2)) {
            gradientOffset = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            goalAnimation = false
            showGoalCelebration = false
            gradientOffset = -1.0
        }
    }
}

//struct AirHockeyGameView: View {
//    @State private var puckPosition = CGPoint(x: 200, y: 400)
//    @State private var puckVelocity = CGVector(dx: 4, dy: 4)
//
//    @State private var player1MalletPosition = CGPoint(x: 200, y: 700)
//    @State private var player2MalletPosition = CGPoint(x: 200, y: 100)
//
//    @State private var player1Score = 0
//    @State private var player2Score = 0
//
//    let puckRadius: CGFloat = 20
//    let malletRadius: CGFloat = 35
//    let goalWidth: CGFloat = 100
//    let timer = Timer.publish(every: 1 / 60, on: .main, in: .common).autoconnect()
//
//    var body: some View {
//        GeometryReader { geometry in
//            ZStack {
//                Color.blue.opacity(0.15).ignoresSafeArea()
//
//                // Rink Border
//                RoundedRectangle(cornerRadius: 20)
//                    .stroke(Color.white, lineWidth: 5)
//                    .padding(10)
//
//                // Center Line
//                Rectangle()
//                    .frame(height: 2)
//                    .foregroundColor(.white)
//                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
//
//                // Player 1 (bottom) Goal Area
//                Rectangle()
//                    .frame(width: goalWidth, height: 5)
//                    .foregroundColor(.green)
//                    .position(x: geometry.size.width / 2, y: geometry.size.height - 10)
//
//                // Player 2 (top) Goal Area
//                Rectangle()
//                    .frame(width: goalWidth, height: 5)
//                    .foregroundColor(.green)
//                    .position(x: geometry.size.width / 2, y: 10)
//
//                // Score Display
//                VStack {
//                    HStack {
//                        Text("Player 1: \(player1Score)")
//                            .foregroundColor(.white)
//                            .font(.title)
//                        Spacer()
//                        Text("Player 2: \(player2Score)")
//                            .foregroundColor(.white)
//                            .font(.title)
//                    }
//                    Spacer()
//                }
//                .padding()
//
//                // Puck
//                Circle()
//                    .fill(Color.black)
//                    .frame(width: puckRadius * 2, height: puckRadius * 2)
//                    .position(puckPosition)
//
//                // Player 1 (bottom) Mallet
//                Circle()
//                    .fill(Color.red)
//                    .frame(width: malletRadius * 2, height: malletRadius * 2)
//                    .position(player1MalletPosition)
//                    .gesture(
//                        DragGesture()
//                            .onChanged { value in
//                                let minY = geometry.size.height / 2 + malletRadius
//                                let maxY = geometry.size.height - malletRadius
//                                let x = min(max(value.location.x, malletRadius), geometry.size.width - malletRadius)
//                                let y = min(max(value.location.y, minY), maxY)
//                                player1MalletPosition = CGPoint(x: x, y: y)
//                            }
//                    )
//
//                // Player 2 (top) Mallet
//                Circle()
//                    .fill(Color.green)
//                    .frame(width: malletRadius * 2, height: malletRadius * 2)
//                    .position(player2MalletPosition)
//                    .gesture(
//                        DragGesture()
//                            .onChanged { value in
//                                let minY = malletRadius
//                                let maxY = geometry.size.height / 2 - malletRadius
//                                let x = min(max(value.location.x, malletRadius), geometry.size.width - malletRadius)
//                                let y = min(max(value.location.y, minY), maxY)
//                                player2MalletPosition = CGPoint(x: x, y: y)
//                            }
//                    )
//            }
//            .onReceive(timer) { _ in
//                updatePuck(in: geometry.size)
//                detectCollision(with: player1MalletPosition)
//                detectCollision(with: player2MalletPosition)
//                checkGoals(in: geometry.size)
//            }
//        }
//    }
//
//    private func updatePuck(in size: CGSize) {
//        puckPosition.x += puckVelocity.dx
//        puckPosition.y += puckVelocity.dy
//
//        // Bounce off walls
//        if puckPosition.x <= puckRadius || puckPosition.x >= size.width - puckRadius {
//            puckVelocity.dx *= -1
//            puckPosition.x = max(puckRadius, min(size.width - puckRadius, puckPosition.x))
//        }
//
//        if puckPosition.y <= puckRadius || puckPosition.y >= size.height - puckRadius {
//            puckVelocity.dy *= -1
//            puckPosition.y = max(puckRadius, min(size.height - puckRadius, puckPosition.y))
//        }
//    }
//
//    private func detectCollision(with malletPosition: CGPoint) {
//        let dx = puckPosition.x - malletPosition.x
//        let dy = puckPosition.y - malletPosition.y
//        let distance = sqrt(dx * dx + dy * dy)
//
//        if distance < puckRadius + malletRadius {
//            // Normalize direction
//            let angle = atan2(dy, dx)
//            let speed: CGFloat = 5
//            puckVelocity.dx = cos(angle) * speed
//            puckVelocity.dy = sin(angle) * speed
//
//            // Move puck out of collision
//            let overlap = puckRadius + malletRadius - distance
//            puckPosition.x += cos(angle) * overlap
//            puckPosition.y += sin(angle) * overlap
//        }
//    }
//
//    private func checkGoals(in size: CGSize) {
//        // Check if puck crosses the goal line
//        if puckPosition.y <= puckRadius {
//            // Player 1 scores!
//            if puckPosition.x > size.width / 2 - goalWidth / 2 && puckPosition.x < size.width / 2 + goalWidth / 2 {
//                player1Score += 1
//                resetPuck(in: size)
//            }
//        }
//
//        if puckPosition.y >= size.height - puckRadius {
//            // Player 2 scores!
//            if puckPosition.x > size.width / 2 - goalWidth / 2 && puckPosition.x < size.width / 2 + goalWidth / 2 {
//                player2Score += 1
//                resetPuck(in: size)
//            }
//        }
//    }
//
//    private func resetPuck(in size: CGSize) {
//        // Reset puck position to the center
//        puckPosition = CGPoint(x: size.width / 2, y: size.height / 2)
//        puckVelocity = CGVector(dx: 4, dy: 4)  // Reset velocity
//    }
//}
