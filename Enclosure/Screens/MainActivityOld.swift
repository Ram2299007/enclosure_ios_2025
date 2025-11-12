import SwiftUI

struct MainActivityOld: View {
    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var isCallEnabled = true
    @State private var isVideoCallEnabled = true
    @State private var isTapped = false
    @State private var isVStackVisible = false
    @State private var isTopHeaderVisible = false
    @State private var isMainContentVisible = true

    @State private var currentBackgroundImage = "bg"
    @State private var currentBackgroundSizeHeight = 140
    @State private var opacity = 0.1
    @State private var viewValue = Constant.chatView




    enum SelectedOption {
        case none, call,videoCall, groupMessage,messageLimit, you;
    }

    @State private var selected: SelectedOption = .none
    var body: some View {
        NavigationStack {
            VStack(spacing:0) {

                if(isMainContentVisible){
                    HStack{
                        Button(action: {
                            withAnimation {

                            }
                        }) {
                            Image("ec_modern")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 55, height: 55)
                        }
                        .frame(width: 70, height: 70)
                        .padding(.leading, 25)

                        Spacer()

                        HStack {
                            if isSearchActive {
                                HStack {
                                    Rectangle()
                                        .fill(Color("blue"))
                                        .frame(width: 1, height: 19.24)
                                        .padding(.leading, 13)

                                    TextField("Search Name", text: $searchText)
                                        .font(.custom("Inter18pt-Regular", size: 15))
                                        .foregroundColor(Color("TextColor"))
                                        .padding(.leading, 13)
                                        .textFieldStyle(PlainTextFieldStyle())

                                }
                                .transition(
                                    .move(edge: .trailing).combined(with: .opacity)
                                ) // डावीकडून यायला आणि अदृश्य व्हायला मदत करेल
                            }

                            Button(action: {
                                withAnimation {
                                    isSearchActive.toggle()
                                }
                            }) {
                                Image("search")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                            }
                            .frame(width: 40, height: 40)
                            .buttonStyle(CircularRippleStyle()) // Apply Ripple effect


                            Button(action: {
                                // Menu action
                            }) {
                                VStack(spacing: 3) {
                                    Circle()
                                        .fill(Color("menuPointColor"))
                                        .frame(width: 4, height: 4)
                                    Circle()
                                        .fill(Color("blue"))
                                        .frame(width: 4, height: 4)
                                    Circle()
                                        .fill(Color("edittextremoveline"))
                                        .frame(width: 4, height: 4)
                                }
                                .frame(width: 30, height: 30)
                            }
                            .frame(width: 40, height: 40)
                            .padding(.trailing,7)
                            .buttonStyle(CircularRippleStyle())// Apply Ripple effect
                        }
                    }





                    // main container
                    VStack (spacing:0){
                        /// 1

                        HStack {
                            Spacer()
                            Button(action: {

                                withAnimation(.easeInOut(duration: 0.30)) {
                                    isVStackVisible.toggle()
                                    currentBackgroundImage = isVStackVisible ? "mainvector" : "bg"
                                    currentBackgroundSizeHeight = isVStackVisible ? 390 : 140
                                    if isVStackVisible {
                                        viewValue = Constant.callView


                                        // Delay opacity to 1 when showing
                                        withAnimation(.easeInOut(duration: 0.30)){
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                                                isTopHeaderVisible = true
                                            }

                                        }



                                    }else{
                                        viewValue = Constant.chatView
                                        isTopHeaderVisible = false


                                    }
                                }

                                if isVStackVisible {
                                    //isTopHeaderVisible = true
                                    selected = .call

                                    // Delay opacity to 1 when showing
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                        withAnimation {
                                            opacity = 1
                                        }
                                    }


                                } else {

                                    // Immediately reduce opacity when hiding
                                    withAnimation {
                                        opacity = 0.0
                                        isTopHeaderVisible = false

                                    }

                                }



                            }) {
                                VStack{
                                    Image("downarrowslide")
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                }
                                .frame(width: 40, height: 40)

                            }
                            .padding(.trailing , 18)
                            .buttonStyle(CircularRippleStyle())
                        }
                        .padding(.top, 69)



                        if isVStackVisible{

                            /// 2
                            VStack{


                                // #1
                                HStack(alignment: .center) {
                                    // Left side: Audio call switch


                                    HStack(spacing: 8) {
                                        Text("Audio call")
                                            .font(.custom("Inter18pt-Medium", size: 15))
                                            .fontWeight(.heavy)
                                            .foregroundColor(.white)
                                            .lineLimit(1)

                                        CustomImageToggle(
                                            isOn: $isCallEnabled,
                                            trackEnabledImage: "blue_radio_btn",      // Image from Assets
                                            trackDisabledImage: "offradiograynew",    // Image from Assets
                                            thumbEnabledImage: "phone.fill",    // SF Symbol or nil
                                            thumbDisabledImage: "xmark"         // SF Symbol or nil
                                        )
                                    }
                                    .padding(.leading, 16)

                                    Spacer()

                                    VStack{

                                        HStack(spacing: 12) {
                                            Spacer()
                                            Text("Call")
                                                .font(.custom("Inter18pt-Medium", size: 15).weight(.bold))
                                                .foregroundColor(selected == .call ? .white : Color("maincontenttextcolor"))
                                                .fontWeight(.heavy)


                                            Image("call") // Make sure this is in your Assets
                                                .resizable()
                                                .frame(width: 24, height: 24)


                                        }
                                        .padding(.trailing,22)

                                    }
                                    .frame(width: 200,height:40)
                                    .background(
                                        selected == .call ? AnyView(Image("bg_rect").resizable()) : AnyView(Color.clear)
                                    )
                                    .onTapGesture {
                                        selected = .call
                                        viewValue = Constant.callView

                                    }

                                }
                                .padding(.top, 5)


                                // #2
                                HStack(alignment: .center) {
                                    // Left side: Audio call switch


                                    HStack(spacing: 8) {
                                        Text("Video call")
                                            .font(.custom("Inter18pt-Medium", size: 15))
                                            .fontWeight(.heavy)
                                            .foregroundColor(.white)
                                            .lineLimit(1)

                                        CustomImageToggle(
                                            isOn: $isVideoCallEnabled,
                                            trackEnabledImage: "blue_radio_btn",      // Image from Assets
                                            trackDisabledImage: "offradiograynew",    // Image from Assets
                                            thumbEnabledImage: "phone.fill",    // SF Symbol or nil
                                            thumbDisabledImage: "xmark"         // SF Symbol or nil
                                        )
                                    }
                                    .padding(.leading, 16)

                                    Spacer()

                                    VStack{

                                        HStack(spacing: 12) {
                                            Spacer()
                                            Text("Video Call")
                                                .font(.custom("Inter18pt-Medium", size: 15).weight(.bold))
                                                .foregroundColor(selected == .videoCall ? .white : Color("maincontenttextcolor"))
                                                .fontWeight(.heavy)


                                            Image("videosvgpoly") // Make sure this is in your Assets
                                                .resizable()
                                                .frame(width: 24, height: 16)


                                        }
                                        .padding(.trailing,22)

                                    }
                                    .frame(width: 200,height:40)
                                    .background(
                                        selected == .videoCall ? AnyView(Image("bg_rect").resizable()) : AnyView(Color.clear)
                                    )
                                    .onTapGesture {
                                        selected = .videoCall
                                        viewValue = Constant.videoCallView

                                    }

                                }
                                .padding(.top, 5)

                                // #3
                                HStack(alignment: .center) {
                                    // Left side: Audio call switch



                                    Spacer()

                                    VStack{

                                        HStack(spacing: 12) {
                                            Spacer()
                                            Text("Group message")
                                                .font(.custom("Inter18pt-Medium", size: 15).weight(.bold))
                                                .foregroundColor(selected == .groupMessage ? .white : Color("maincontenttextcolor"))
                                                .fontWeight(.heavy)


                                            Image("group_new_svg") // Make sure this is in your Assets
                                                .resizable()
                                                .frame(width: 24, height: 24)


                                        }
                                        .padding(.trailing,22)

                                    }
                                    .frame(width: 200,height:40)
                                    .background(
                                        selected == .groupMessage ? AnyView(Image("bg_rect").resizable()) : AnyView(Color.clear)
                                    )
                                    .onTapGesture {
                                        selected = .groupMessage
                                        viewValue = Constant.groupMsgView
                                    }

                                }
                                .padding(.top, 5)

                                // #4
                                HStack(alignment: .center) {
                                    // Left side: Audio call switch



                                    Spacer()

                                    VStack{

                                        HStack(spacing: 12) {
                                            Spacer()
                                            Text("Message Limit")
                                                .font(.custom("Inter18pt-Medium", size: 15).weight(.bold))
                                                .foregroundColor(selected == .messageLimit ? .white : Color("maincontenttextcolor"))
                                                .fontWeight(.heavy)


                                            Image("limit") // Make sure this is in your Assets
                                                .resizable()
                                                .frame(width: 24, height: 24)


                                        }
                                        .padding(.trailing,22)

                                    }
                                    .frame(width: 200,height:40)
                                    .background(
                                        selected == .messageLimit ? AnyView(Image("bg_rect").resizable()) : AnyView(Color.clear)
                                    )
                                    .onTapGesture {
                                        selected = .messageLimit
                                        viewValue = Constant.messageLmtView
                                    }

                                }
                                .padding(.top, 5)


                                // #5
                                HStack(alignment: .center) {
                                    // Left side: Audio call switch

                                    Spacer()

                                    VStack{

                                        HStack(spacing: 12) {
                                            Spacer()
                                            Text("You")
                                                .font(.custom("Inter18pt-Medium", size: 15).weight(.bold))
                                                .foregroundColor(selected == .you ? .white : Color("maincontenttextcolor"))
                                                .fontWeight(.heavy)


                                            Image("you") // Make sure this is in your Assets
                                                .resizable()
                                                .frame(width: 18, height: 24)


                                        }
                                        .padding(.trailing,22)

                                    }
                                    .frame(width: 200,height:40)
                                    .background(
                                        selected == .you ? AnyView(Image("bg_rect").resizable()) : AnyView(Color.clear)
                                    )
                                    .onTapGesture {
                                        selected = .you
                                        viewValue = Constant.youView

                                    }
                                }
                                .padding(.top, 5)
                            }
                            .padding(.top,13)
                            .opacity(isVStackVisible ? opacity : opacity)


                        }



                        Spacer()

                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: CGFloat(currentBackgroundSizeHeight))
                    .background(
                        Image(currentBackgroundImage)
                            .resizable()

                    )


                }


                if(isTopHeaderVisible){
                    VStack{

                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 10)
                    .background(Color("appThemeColor"))
                }



                // TODO:  Children are styarting from here

                VStack(spacing:0){

                    if(viewValue == Constant.chatView){

                        chatView()


                    }else if(viewValue == Constant.callView){

                        callView(isMainContentVisible: $isMainContentVisible)

                    }else if(viewValue == Constant.videoCallView){

                        videoCallView(isMainContentVisible: $isMainContentVisible)

                    }else if(viewValue == Constant.groupMsgView){

                        groupMessageView(isMainContentVisible: $isMainContentVisible)
                    }else if(viewValue == Constant.messageLmtView){

                        messageLmtView(isMainContentVisible: $isMainContentVisible)



                    }else if(viewValue == Constant.youView){

                        youView(isMainContentVisible: $isMainContentVisible)
                    }
                }






            }
            .background(Color("background_color"))
           
        }

        .navigationBarHidden(true)
    }


    struct CircularRippleStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .background(
                    ZStack {
                        if configuration.isPressed {
                            Circle()
                                .fill(Color("circlebtnhover").opacity(0.3)) // Adjust ripple color and opacity
                                .frame(width: 40, height: 40) // Adjust ripple size
                        }


                    }
                )
                .scaleEffect(configuration.isPressed ? 1.1 : 1.0) // Add a slight scale effect
                .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        }
    }
}

struct MainActivityOld_Previews: PreviewProvider {
    static var previews: some View {
        MainActivityOld()
    }
}
