//
//  StudentLoginConfirmView.swift
//  CampuraOne
//

import SwiftUI

#Preview {
    StudentLoginConfirmView(user: .init(userID: 1, userName: "userName"), student: .init(studentID: 1, studentName: "studentName", schoolID: 1, compoundID: 1, departmentID: 1, classID: 1)) {
        
    }
}

struct StudentLoginConfirmView: View {
    let user: AppUser
    let student: Student?
    var onContinue: (() -> Void)? = nil

    var body: some View {
        ZStack {
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "person.text.rectangle.fill")
                    Text("请确认信息：")
                }
                    .font(.title)
                    .padding(.vertical)
                
                userName()
                    .padding(.bottom)
                
                userInfo()
                    .padding(.bottom)
                
                Spacer()
                Text("我已确认无误，开始使用")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(.blue)
                    .beButton {
                        
                    }
                
                
                    .highPriorityGesture(celebrateTapPosition())
                    .buttonStyle(CelebrationConfettiButtonStyle())
                    
                    .ignoresSafeArea()
            }
            .padding(.horizontal)
        }
        .navigationTitle("登录成功🎉")
//        .animation(.smooth, value: show格式错误AlertMINI)
        .navigationBarBackButtonHidden()
    }

    @ViewBuilder
    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .leading)
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct userName: View {
    @State var showChangeName = false
    @State var newUserName = ""
    @FocusState var showNameKeyboard
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: "person.fill")
                
                Text("用户名")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            
            
        }
    }
    
}

struct userInfo: View {
    
    @State var showPhone = false
    @State var showEmail = false
    @State var showOutlook = false
    @State var showAppleID = false
    
    var body: some View {
        VStack {
            infoCard(title: "手机号", sf: "phone.fill", content: "18071077418", showBool: showPhone)
            
            infoCard(title: "邮箱地址", sf: "envelope.fill", content: "3364006414@qq.com", showBool: showEmail)
            
            infoCard(title: "微软账户", sf: "微软logo", content: "3364006414@outlook.com", showBool: showOutlook)
            
            infoCard(title: "Apple ID", sf: "apple.logo", content: "lshayc1own@icloud.com", showBool: showAppleID)
            
        }
    }
    
    
    @State var showAlert = false
    
    @ViewBuilder
    func notBinding(title: String, sf: String) -> some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    if sf == "微软logo" {
                        Image(sf)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24.4)
                            .padding(.horizontal, (40-24.4)/2)
                    } else {
                        Image(systemName: sf)
                            .symbolRenderingMode(.multicolor)
                            .frame(width: 40)
                    }
                   
                    Text(title)
                    if title == "手机号" {
                        Text("86")
                            .font(.system(size: 14))
                            .bold()
                            .padding(3)
                            .background {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(.green.opacity(1/3))
                            }
                        
                            
                    }
                }
                .font(.title3)
                
                HStack {
                    if sf == "微软logo" {
                        Image(systemName: "envelope")
                            .frame(width: 40)
                            .opacity(0)
                    } else {
                        Image(systemName: sf)
                            .frame(width: 40)
                            .opacity(0)
                    }
                    Text("尚未绑定\(title)噢")
                    
                }
            }
            
            
            Spacer()
            
            
            VStack {
                Text("去绑定")
            }
            
            .beButton {
//                withAnimation(.bouncy) {
                    //去绑定
                    showAlert = true
//                }
            }
            .buttonStyle(.bordered)
            .alert("暂不支持绑定，请等待更新", isPresented: $showAlert) {
                Text("好的")
                    .beButton {
                        
                    }
            }
        }
    }
    
}




struct infoCard: View {
    @State var title: String
    @State var sf: String
    @State var content: String
    @State var showBool: Bool
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    if sf == "微软logo" {
                        Image(sf)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24.4)
                            .padding(.horizontal, (40-24.4)/2)
                    } else {
                        Image(systemName: sf)
                            .symbolRenderingMode(.multicolor)
                            .frame(width: 40)
                    }
                   
                    Text(title)
                    if title == "手机号" {
                        Text("86")
                            .font(.system(size: 14))
                            .bold()
                            .padding(3)
                            .background {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(.green.opacity(1/3))
                            }
                        
                            
                    }
                }
                .font(.title3)
                
                
                HStack {
                    if sf == "微软logo" {
                        Image(systemName: "envelope")
                            .frame(width: 40)
                            .opacity(0)
                    } else {
                        Image(systemName: sf)
                            .frame(width: 40)
                            .opacity(0)
                    }
                    if showBool {
                        Text(content)
                    } else {
                        Text(content)
                       
                    }
                    
                }
            }
            
            
            Spacer()
            
            
            VStack {
                if showBool {
                    Image(systemName: "eyes")
                } else {
                    Image(systemName: "eyes.inverse")
                        .rotationEffect(.degrees(180), anchor: .center)
                }
            }
            .font(.system(size: 18))
            
            .beButton {
                withAnimation(.bouncy) {
                    showBool.toggle()
                }
            }
            .buttonStyle(.plain)
        }
    }
}

