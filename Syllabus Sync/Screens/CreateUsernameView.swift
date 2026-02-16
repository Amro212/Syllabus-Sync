//
//  CreateUsernameView.swift
//  Syllabus Sync
//
//  Shown inside SocialHubView when the user hasn't set a username yet.
//  Blocks access to friend features until a valid username is saved.
//

import SwiftUI

struct CreateUsernameView: View {
    @ObservedObject var viewModel: SocialHubViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SOCIAL HUB")
                    .font(.lexend(size: 24, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Button {
                    HapticFeedbackManager.shared.lightImpact()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.lexend(size: 18, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(AppColors.surfaceSecondary)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, Layout.Spacing.lg)
            .padding(.top, Layout.Spacing.md)

            Spacer()

            // Card
            VStack(spacing: Layout.Spacing.xl) {
                Image(systemName: "person.badge.plus")
                    .font(.lexend(size: 48, weight: .regular))
                    .foregroundColor(AppColors.accent)

                VStack(spacing: Layout.Spacing.sm) {
                    Text("Create Your Username")
                        .font(.lexend(size: 22, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)

                    Text("Choose a unique username to connect with classmates and share your schedule.")
                        .font(.lexend(size: 14, weight: .regular))
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Input field
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Choose a username", text: Binding(
                        get: { viewModel.usernameInput },
                        set: { newValue in
                            viewModel.usernameInput = newValue
                            viewModel.validateUsernameInput(newValue)
                        }
                    ))
                    .font(.lexend(size: 16, weight: .regular))
                    .foregroundColor(AppColors.textPrimary)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                            .fill(AppColors.surfaceSecondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                                    .stroke(
                                        viewModel.usernameError != nil
                                            ? Color.red.opacity(0.6)
                                            : isFocused
                                                ? AppColors.accent.opacity(0.5)
                                                : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                    )

                    if let error = viewModel.usernameError {
                        Text(error)
                            .font(.lexend(size: 12, weight: .regular))
                            .foregroundColor(.red.opacity(0.9))
                    } else {
                        Text("3-20 characters, letters, numbers, and underscore only")
                            .font(.lexend(size: 12, weight: .regular))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }

                // Save button
                Button {
                    HapticFeedbackManager.shared.mediumImpact()
                    Task { await viewModel.saveUsername() }
                } label: {
                    HStack {
                        if viewModel.isSavingUsername {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("Continue")
                                .font(.lexend(size: 17, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: Layout.CornerRadius.xl)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.886, green: 0.714, blue: 0.275),
                                        Color(red: 0.816, green: 0.612, blue: 0.118)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: AppColors.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(viewModel.usernameInput.count < 3 || viewModel.usernameError != nil || viewModel.isSavingUsername)
                .opacity(viewModel.usernameInput.count < 3 || viewModel.usernameError != nil ? 0.5 : 1.0)
            }
            .padding(Layout.Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: Layout.CornerRadius.xxl)
                    .fill(AppColors.surface)
            )
            .padding(.horizontal, Layout.Spacing.lg)

            Spacer()
        }
        .onAppear { isFocused = true }
    }
}
