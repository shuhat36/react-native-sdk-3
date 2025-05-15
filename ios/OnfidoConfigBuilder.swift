//
//  OnfidoConfigBuilder.swift
//
//  Copyright © 2016-2024 Onfido. All rights reserved.
//

import Foundation
import Onfido

struct OnfidoConfigBuilder {
    enum OnfidoMode {
        case classic(configBuilder: Onfido.OnfidoConfigBuilder)
        case studio(workflowConfig: Onfido.WorkflowConfiguration)
    }
    
    func build(
        config: OnfidoPluginConfig,
        appearance: Appearance,
        mediaCallBack: CallbackReceiver?,
        encryptedBiometricTokenHandler: EncryptedBiometricTokenHandlerReceiver?
    ) throws -> OnfidoMode {
        guard let workflowId = config.workflowRunId else {
            return try buildClassic(config: config, appearance: appearance, mediaCallBack: mediaCallBack)
        }
        
        return try buildStudio(
            workflowId: workflowId,
            config: config,
            appearance: appearance,
            mediaCallBack: mediaCallBack,
            encryptedBiometricTokenHandler: encryptedBiometricTokenHandler
        )
    }
    
    // MARK: - Studio
    
    private func buildStudio(
        workflowId: String,
        config: OnfidoPluginConfig,
        appearance: Appearance,
        mediaCallBack: CallbackReceiver?,
        encryptedBiometricTokenHandler: EncryptedBiometricTokenHandlerReceiver?
    ) throws -> OnfidoMode {
        var workflowConfig = WorkflowConfiguration(workflowRunId: workflowId, sdkToken: config.sdkToken)
        
        // Enterprise features
        let enterpriseFeatures = try enterpriseFeatures(for: config)
        workflowConfig = workflowConfig.withEnterpriseFeatures(enterpriseFeatures)
        
        // Appearance
        workflowConfig = workflowConfig.withAppearance(appearance)
        
        // Localization
        if let localizationFile = try customLocalization(config: config) {
            workflowConfig = workflowConfig.withCustomLocalization(withTableName: localizationFile, in: .main)
        }
        
        // Media Callback
        if let mediaCallBack {
            workflowConfig = workflowConfig.withMediaCallback(mediaCallback: mediaCallBack)
         }

        // Encrypted biometric token handler
        if let encryptedBiometricTokenHandler {
            workflowConfig = workflowConfig.withEncryptedBiometricTokenHandler(handler: encryptedBiometricTokenHandler)
        }

        return .studio(workflowConfig: workflowConfig)
    }
    
    // MARK: - Classic
    
    private func buildClassic(
        config: OnfidoPluginConfig,
        appearance: Appearance,
        mediaCallBack: CallbackReceiver?
    ) throws -> OnfidoMode {
        let builder = OnfidoConfig.builder()
            .withSDKToken(config.sdkToken)
            .withAppearance(appearance)
        
        // Flow steps
        try configureClassicSteps(builder: builder, config: config)
        
        // Enterprise features
        let enterpriseFeatures = try enterpriseFeatures(for: config)
        builder.withEnterpriseFeatures(enterpriseFeatures)
        
        // NFC
        if let disableNFC = config.disableNFC, disableNFC == true {
            builder.withNFC(.off)
        }
        
        // Localization
        if let localizationFile = try customLocalization(config: config) {
            builder.withCustomLocalization(andTableName: localizationFile)
        }

        builder.withNFC(nfcConfiguration(config: config))
        
        // Media Callback
        if let mediaCallBack {
            builder.withMediaCallback(mediaCallback: mediaCallBack)
        }
        
        return .classic(configBuilder: builder)
    }
    
    private func configureClassicSteps(builder: Onfido.OnfidoConfigBuilder, config: OnfidoPluginConfig) throws {
        guard let steps = config.flowSteps else { return }
        
        // Welcome
        if let hasWelcome = steps.welcome, hasWelcome == true {
            builder.withWelcomeStep()
        }

        // Proof of Address
        if let isProofOfAddressEnabled = steps.proofOfAddress, isProofOfAddressEnabled {
            builder.withProofOfAddressStep()
        }
        
        try configureDocumentStep(builder: builder, steps: steps)
        configureBioStep(builder: builder, steps: steps)
    }
    
    // MARK: - Document step
    
    private func configureDocumentStep(builder: Onfido.OnfidoConfigBuilder, steps: OnfidoFlowSteps) throws {
        if let docType = steps.captureDocument?.docType, let countryCode = steps.captureDocument?.countryCode {
            switch docType {
            case .passport:
                builder.withDocumentStep(type: .passport(config: PassportConfiguration()))
            case .drivingLicence:
                builder.withDocumentStep(
                    type: .drivingLicence(config: DrivingLicenceConfiguration(country: countryCode))
                )
            case .nationalIdentityCard:
                builder.withDocumentStep(
                    type: .nationalIdentityCard(config: NationalIdentityConfiguration(country: countryCode))
                )
            case .residencePermit:
                builder.withDocumentStep(
                    type: .residencePermit(config: ResidencePermitConfiguration(country: countryCode))
                )
            case .visa:
                builder.withDocumentStep(type: .visa(config: VisaConfiguration(country: countryCode)))
            case .workPermit:
                builder.withDocumentStep(
                    type: .workPermit(config: WorkPermitConfiguration(country: countryCode))
                )
            case .generic:
                builder.withDocumentStep(
                    type: .generic(config: GenericDocumentConfiguration(country: countryCode))
                )
            }

        } else if let allowedDocumentTypes = steps.captureDocument?.allowedDocumentTypes {
            guard allowedDocumentTypes.isEmpty == false else {
                builder.withDocumentStep()
                return
            }

            var selectableTypes: [SelectableDocumentType] = []
            for docType in allowedDocumentTypes {
                switch docType {
                    case .passport:
                        selectableTypes.append(SelectableDocumentType.passport)
                    case .drivingLicence:
                        selectableTypes.append(SelectableDocumentType.drivingLicence)
                    case .nationalIdentityCard:
                        selectableTypes.append(SelectableDocumentType.identityCard)
                    case .residencePermit:
                        selectableTypes.append(SelectableDocumentType.residencePermit)
                    default:
                        throw NSError(domain: "Unsupported document type", code: 0)
                }
            }
            builder.withDocumentStep(ofSelectableTypes: selectableTypes)

        } else if steps.captureDocument != nil {
            builder.withDocumentStep()
        }
    }
    
    // MARK: - Bio step
    
    private func configureBioStep(builder: Onfido.OnfidoConfigBuilder, steps: OnfidoFlowSteps) {
        let captureFace = steps.captureFace
        guard let faceVariant = captureFace?.type else {
            return
        }

        let shouldShowIntro = captureFace?.showIntro ?? true
        let shouldUseManualVideoCapture = captureFace?.manualVideoCapture ?? false
        let shouldRecordAudio = captureFace?.recordAudio ?? false

        switch faceVariant {
        case .photo:
            builder.withFaceStep(ofVariant: .photo(withConfiguration: .init(showSelfieIntroScreen: shouldShowIntro)))
        case .video:
            builder.withFaceStep(ofVariant: .video(withConfiguration: .init(
                showIntroVideo: shouldShowIntro,
                manualLivenessCapture: shouldUseManualVideoCapture
            )))
        case .motion:
            builder.withFaceStep(ofVariant: .motion(withConfiguration: .init(recordAudio: shouldRecordAudio)))
        }
    }
    
    // MARK: - Enterprise features
    
    private func enterpriseFeatures(for config: OnfidoPluginConfig) throws -> EnterpriseFeatures {
        let enterpriseFeatures = EnterpriseFeatures.builder()
        
        if let hideLogo = config.hideLogo, hideLogo {
            enterpriseFeatures.withHideOnfidoLogo(hideLogo)
        }
        
        if let logoCoBrand = config.logoCoBrand, logoCoBrand == true {
            guard let cobrandLogo = UIImage(named: "cobrand-logo-light"),
                  let cobrandLogoDark = UIImage(named: "cobrand-logo-dark")
            else {
                throw NSError(domain: "Cobrand logos were not found", code: 0)
            }
            enterpriseFeatures.withCobrandingLogo(cobrandLogo, cobrandingLogoDarkMode: cobrandLogoDark)
        }
        
        if let disableMobileSdkAnalytics = config.disableMobileSdkAnalytics, disableMobileSdkAnalytics {
            enterpriseFeatures.withDisableMobileSdkAnalytics(disableMobileSdkAnalytics)
        }
        
        return enterpriseFeatures.build()
    }
    
    // MARK: - Localisation
    
    private func customLocalization(config: OnfidoPluginConfig) throws -> String? {
        return config.localisation?.stringsFileName
    }
    
    // MARK: - NFC Configurations

    private func nfcConfiguration(config: OnfidoPluginConfig) -> NFCConfiguration {
        let nfcConfigurationMap: [OnfidoNFCOptions?: NFCConfiguration] = [
            OnfidoNFCOptions.disabled: .off,
            OnfidoNFCOptions.optional: .optional,
            OnfidoNFCOptions.required: .required
        ]
        return nfcConfigurationMap[config.nfcOption, default: .optional]
    }
    
    // MARK: - Helpers
    
    private func colorFrom(hex: String?, fallback: UIColor) -> UIColor {
        guard let hex else { 
            return fallback 
        }
        
        let hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let scanner = Scanner(string: hexString)
        
        if hexString.hasPrefix("#") {
            scanner.scanLocation = 1
        }
        
        var color: UInt32 = 0
        scanner.scanHexInt32(&color)
        
        let mask = 0x000000ff
        let redInt = Int(color >> 16) & mask
        let greenInt = Int(color >> 8) & mask
        let blueInt = Int(color) & mask
        
        let red = CGFloat(redInt) / 255.0
        let green = CGFloat(greenInt) / 255.0
        let blue = CGFloat(blueInt) / 255.0
        
        return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
    }
}
