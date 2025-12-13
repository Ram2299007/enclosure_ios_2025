//
//  CustomActionSheet.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import SwiftUI

struct CustomActionSheet: View {
    @Binding var isPresented: Bool
    let title: String
    let options: [ActionSheetOption]
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            if isPresented {
                // Normal background overlay (no blur)
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isPresented = false
                        }
                    }
                
                // Action sheet content
                VStack {
                    Spacer()
                    
                    VStack(spacing: 0) {
                        // Title section
                        if !title.isEmpty {
                            Text(title)
                                .font(.custom("Inter18pt-Medium", size: 16))
                                .foregroundColor(Color("TextColor"))
                                .padding(.vertical, 18)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color("chattingMessageBox"))
                                )
                        }
                        
                        // Options
                        VStack(spacing: 0) {
                            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        isPresented = false
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        option.action()
                                    }
                                }) {
                                    Text(option.title)
                                        .font(.custom("Inter18pt-Medium", size: 16))
                                        .foregroundColor(option.isDestructive ? .red : Color("TextColor"))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 18)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                if index < options.count - 1 {
                                    Divider()
                                        .background(Color("TextColor").opacity(0.2))
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color("chattingMessageBox"))
                        )
                        .padding(.top, title.isEmpty ? 0 : 8)
                        
                        // Cancel button
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isPresented = false
                            }
                        }) {
                            Text("Cancel")
                                .font(.custom("Inter18pt-Medium", size: 16))
                                .foregroundColor(Color("TextColor"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color("chattingMessageBox"))
                        )
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 34)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPresented)
    }
}

struct ActionSheetOption {
    let title: String
    let action: () -> Void
    let isDestructive: Bool
    
    init(_ title: String, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.action = action
        self.isDestructive = isDestructive
    }
}

