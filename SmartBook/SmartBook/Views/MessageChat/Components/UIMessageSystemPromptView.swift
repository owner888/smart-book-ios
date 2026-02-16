//
//  UIMessageSystemPromptView.swift
//  SmartBook
//
//  Extracted from MessageDisplayView.swift
//

import SwiftUI
import UIKit

final class UIMessageSystemPromptView: UIView {
    
    // MARK: - Properties
    private var prompt: String = ""
    private var isExpanded: Bool = false
    private var colors = ThemeColors.dark
    
    // MARK: - UI Components
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
     
    private let containerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var headerButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.configuration = nil
        
        let config = UIImage.SymbolConfiguration(pointSize: 12)
        let chevronImage = UIImage(systemName: "chevron.right", withConfiguration: config)
        
        var configBuilder = UIButton.Configuration.plain()
        configBuilder.image = UIImage(systemName: "doc.text")
        configBuilder.imagePlacement = .leading
        configBuilder.imagePadding = 4
        configBuilder.title = L("chat.systemPrompt.title")
        configBuilder.baseForegroundColor = .label
        
        button.configuration = configBuilder
        button.addTarget(self, action: #selector(headerTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var chevronImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 12)
        imageView.image = UIImage(systemName: "chevron.right", withConfiguration: config)
        imageView.tintColor = .label
        return imageView
    }()
    
    private let promptLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12)
        label.numberOfLines = 0
        return label
    }()
    
    private let promptContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
        return view
    }()
    
    private var promptHeightConstraint: NSLayoutConstraint?
    
    // MARK: - Initialization
    
    func configure(prompt: String, colors: ThemeColors = .dark) {
        self.prompt = prompt
        self.colors = colors
        updateAppearance()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        addSubview(containerStack)
        // Header button
        let headerStack = UIStackView(arrangedSubviews: [
            createIconImageView(named: "doc.text"),
            createTitleLabel(),
            chevronImageView
        ])
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Prompt container with label
        promptContainer.addSubview(promptLabel)
        
        NSLayoutConstraint.activate([
            promptLabel.topAnchor.constraint(equalTo: promptContainer.topAnchor, constant: 8),
            promptLabel.leadingAnchor.constraint(equalTo: promptContainer.leadingAnchor, constant: 8),
            promptLabel.trailingAnchor.constraint(equalTo: promptContainer.trailingAnchor, constant: -8),
            promptLabel.bottomAnchor.constraint(equalTo: promptContainer.bottomAnchor, constant: -8),
            
            containerStack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            containerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            containerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            containerStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])
        
        containerStack.addArrangedSubview(headerStack)
        containerStack.addArrangedSubview(promptContainer)
        
        // Initially collapsed
        promptContainer.isHidden = true
        promptHeightConstraint = promptContainer.heightAnchor.constraint(equalToConstant: 0)
        promptHeightConstraint?.isActive = true
        
        // Add tap gesture to header
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(headerTapped))
        headerStack.isUserInteractionEnabled = true
        headerStack.addGestureRecognizer(tapGesture)
        
        // Setup border and background
        setupBorderAndBackground()
    }
    
    private func createIconImageView(named systemName: String) -> UIImageView {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 12)
        imageView.image = UIImage(systemName: systemName, withConfiguration: config)
        imageView.tintColor = UIColor(colors.accentColor)
        return imageView
    }
    
    private func createTitleLabel() -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = L("chat.systemPrompt.title")
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor(colors.primaryText)
        return label
    }
    
    private func setupBorderAndBackground() {
        promptContainer.backgroundColor = UIColor(colors.accentColor).withAlphaComponent(0.1)
        layer.cornerRadius = 8
        clipsToBounds = true
        
        // Add border
        let borderLayer = CAShapeLayer()
        borderLayer.strokeColor = UIColor(colors.accentColor).withAlphaComponent(0.3).cgColor
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.lineWidth = 1
        borderLayer.path = UIBezierPath(roundedRect: bounds, cornerRadius: 8).cgPath
        borderLayer.frame = bounds
        layer.addSublayer(borderLayer)
    }
    
    private func updateAppearance() {
        promptLabel.text = prompt
        promptLabel.textColor = UIColor(colors.secondaryText)
    }
    
    // MARK: - Actions
    
    @objc private func headerTapped() {
        toggleExpanded()
    }
    
    func toggleExpanded() {
        isExpanded.toggle()
        
        let imageName = isExpanded ? "chevron.down" : "chevron.right"
        let config = UIImage.SymbolConfiguration(pointSize: 12)
        let image = UIImage(systemName: imageName, withConfiguration: config)
        
        UIView.animate(withDuration: 0.25) {
            self.chevronImageView.image = image
        }
        
        promptContainer.isHidden = !isExpanded
        
        if isExpanded {
            promptHeightConstraint?.isActive = false
            promptContainer.layoutIfNeeded()
            
            let height = promptLabel.sizeThatFits(
                CGSize(width: promptContainer.bounds.width - 16, height: .greatestFiniteMagnitude)
            ).height + 16
            
            promptHeightConstraint = promptContainer.heightAnchor.constraint(equalToConstant: height)
            promptHeightConstraint?.isActive = true
            
            UIView.animate(withDuration: 0.25) {
                self.layoutIfNeeded()
            }
        } else {
            promptHeightConstraint?.isActive = false
            promptHeightConstraint = promptContainer.heightAnchor.constraint(equalToConstant: 0)
            promptHeightConstraint?.isActive = true
            
            UIView.animate(withDuration: 0.25) {
                self.layoutIfNeeded()
            } completion: { _ in
                self.promptContainer.isHidden = true
            }
        }
    }
    
    func setExpanded(_ expanded: Bool, animated: Bool = true) {
        guard animated else {
            isExpanded = expanded
            promptContainer.isHidden = !expanded
            let imageName = expanded ? "chevron.down" : "chevron.right"
            chevronImageView.image = UIImage(systemName: imageName)
            return
        }
        
        if isExpanded != expanded {
            toggleExpanded()
        }
    }
}
