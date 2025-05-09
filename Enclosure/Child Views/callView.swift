//
//  callView.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import Foundation
import SwiftUICore
import SwiftUI


struct callView: View {
    @State private var dragOffset: CGSize = .zero
    @State private var isStretchedUp = false
    @State private var isButtonVisible = false
    @Binding var isMainContentVisible: Bool
    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 0) {

            if(isButtonVisible){
                Button(action: {
                    withAnimation {
                        isPressed = true
                        isStretchedUp = false
                        isMainContentVisible = true


                         withAnimation(.easeInOut(duration: 0.30)){
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isButtonVisible = false
                                isPressed = false
                            }
                        }

                    }

                }) {
                    ZStack {
                        if isPressed {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 40, height: 40)
                                .scaleEffect(isPressed ? 1.2 : 1.0)
                                .animation(.easeOut(duration: 0.1), value: isPressed)
                        }

                        Image("leftvector")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 18)
                            .foregroundColor(Color("icontintGlobal"))
                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { _ in
                            withAnimation {
                                isPressed = false
                            }
                        }
                )

                .padding(.leading, 20)
                .padding(.bottom,30)
                .frame(maxWidth: .infinity, alignment: .leading)
            }



            Text("This is the callView")
            Spacer()


        }
        .padding(.top,15)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear.contentShape(Rectangle())) // Make whole area touchable
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    withAnimation(.easeInOut(duration: 0.30)) {
                        if value.translation.height < -50 {
                            // Stretched upward
                            isStretchedUp = true
                            isMainContentVisible = false
                            // isTopHeaderVisible = true
                            print("Stretched upward!")
                            isButtonVisible = true
                        } else if value.translation.height > 50 {
                            withAnimation {
                                isPressed = true
                                isStretchedUp = false
                                isMainContentVisible = true


                                 withAnimation(.easeInOut(duration: 0.30)){
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isButtonVisible = false
                                        isPressed = false
                                    }
                                }

                            }

                        }
                        dragOffset = .zero
                    }
                }
        )
        .animation(.spring(), value: dragOffset)
    }
}


