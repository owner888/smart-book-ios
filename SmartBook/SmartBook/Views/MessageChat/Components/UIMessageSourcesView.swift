//
//  UIMessageSourcesView.swift
//  SmartBook
//
//  Extracted from MessageDisplayView.swift
//

import SwiftUI
import UIKit

final class UIMessageSourcesView: UIView {

    // MARK: - Properties
    private var sources: [RAGSource] = []
    private var isExpanded: Bool = false
    private var colors = ThemeColors.dark

    // MARK: - UI Components
    required override init(frame: CGRect) {
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

    private lazy var chevronImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 12)
        imageView.image = UIImage(
            systemName: "chevron.right",
            withConfiguration: config
        )
        imageView.tintColor = .label
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12, weight: .medium)
        return label
    }()

    private let sourcesStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 6
        return stack
    }()

    private var sourcesContainerHeightConstraint: NSLayoutConstraint?

    // MARK: - Initialization

    func config(
        sources: [RAGSource],
        colors: ThemeColors = .dark,
        isExpanded: Bool = false
    ) {
        self.sources = sources
        self.colors = colors
        self.isExpanded = isExpanded
        setupUI()
        updateAppearance()
    }

    private func setupUI() {
        addSubview(containerStack)

        // Header
        let headerStack = createHeaderStack()

        // Sources container
        let sourcesContainer = UIView()
        sourcesContainer.translatesAutoresizingMaskIntoConstraints = false
        sourcesContainer.addSubview(sourcesStackView)

        NSLayoutConstraint.activate([
            sourcesStackView.topAnchor.constraint(
                equalTo: sourcesContainer.topAnchor
            ),
            sourcesStackView.leadingAnchor.constraint(
                equalTo: sourcesContainer.leadingAnchor
            ),
            sourcesStackView.trailingAnchor.constraint(
                equalTo: sourcesContainer.trailingAnchor
            ),
            sourcesStackView.bottomAnchor.constraint(
                equalTo: sourcesContainer.bottomAnchor
            ),

            containerStack.topAnchor.constraint(
                equalTo: topAnchor,
                constant: 8
            ),
            containerStack.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: 8
            ),
            containerStack.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -8
            ),
            containerStack.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -8
            ),
        ])

        containerStack.addArrangedSubview(headerStack)
        containerStack.addArrangedSubview(sourcesContainer)

        // Initially collapsed
        sourcesContainer.isHidden = true
        sourcesContainerHeightConstraint = sourcesContainer.heightAnchor
            .constraint(equalToConstant: 0)
        sourcesContainerHeightConstraint?.isActive = true

        setupBorderAndBackground()
    }

    private func createHeaderStack() -> UIStackView {
        let iconImageView = UIImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 12)
        iconImageView.image = UIImage(
            systemName: "books.vertical",
            withConfiguration: config
        )
        iconImageView.tintColor = .green

        let headerStack = UIStackView(arrangedSubviews: [
            iconImageView, titleLabel, chevronImageView,
        ])
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 16),
            iconImageView.heightAnchor.constraint(equalToConstant: 16),
        ])

        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(headerTapped)
        )
        headerStack.isUserInteractionEnabled = true
        headerStack.addGestureRecognizer(tapGesture)

        return headerStack
    }

    private func setupBorderAndBackground() {
        let greenColor = UIColor.green

        layer.cornerRadius = 8
        clipsToBounds = true

        // Add border layer
        let borderLayer = CAShapeLayer()
        borderLayer.strokeColor = greenColor.withAlphaComponent(0.3).cgColor
        borderLayer.fillColor = greenColor.withAlphaComponent(0.05).cgColor
        borderLayer.lineWidth = 1
        borderLayer.path =
            UIBezierPath(roundedRect: bounds, cornerRadius: 8).cgPath
        borderLayer.frame = bounds
        layer.addSublayer(borderLayer)
    }

    private func updateAppearance() {
        titleLabel.text = L("chat.sources.title", sources.count)
        titleLabel.textColor = UIColor(colors.primaryText)
        rebuildSourcesStack()
    }

    private func rebuildSourcesStack() {
        sourcesStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for source in sources.prefix(3) {
            let sourceView = createSourceRow(source: source)
            sourcesStackView.addArrangedSubview(sourceView)
        }
    }

    private func createSourceRow(source: RAGSource) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor.green.withAlphaComponent(0.05)
        container.layer.cornerRadius = 6

        // Score percentage label
        let scoreLabel = UILabel()
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false
        scoreLabel.text = "\(source.scorePercentage)%"
        scoreLabel.font = .systemFont(ofSize: 11, weight: .bold)
        scoreLabel.textColor = .green
        scoreLabel.textAlignment = .center

        // Score background (Capsule)
        let scoreContainer = UIView()
        scoreContainer.translatesAutoresizingMaskIntoConstraints = false
        scoreContainer.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        scoreContainer.layer.cornerRadius = 8

        // Source text
        let textLabel = UILabel()
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.text = source.text
        textLabel.font = .systemFont(ofSize: 12)
        textLabel.textColor = UIColor(colors.secondaryText)
        textLabel.numberOfLines = 3

        container.addSubview(scoreContainer)
        container.addSubview(scoreLabel)
        container.addSubview(textLabel)

        NSLayoutConstraint.activate([
            scoreContainer.topAnchor.constraint(
                equalTo: container.topAnchor,
                constant: 2
            ),
            scoreContainer.leadingAnchor.constraint(
                equalTo: container.leadingAnchor,
                constant: 2
            ),
            scoreContainer.bottomAnchor.constraint(
                equalTo: container.bottomAnchor,
                constant: -2
            ),
            scoreContainer.widthAnchor.constraint(
                greaterThanOrEqualToConstant: 40
            ),
            scoreContainer.heightAnchor.constraint(equalToConstant: 20),

            scoreLabel.centerXAnchor.constraint(
                equalTo: scoreContainer.centerXAnchor
            ),
            scoreLabel.centerYAnchor.constraint(
                equalTo: scoreContainer.centerYAnchor
            ),
            scoreLabel.leadingAnchor.constraint(
                equalTo: scoreContainer.leadingAnchor,
                constant: 6
            ),
            scoreLabel.trailingAnchor.constraint(
                equalTo: scoreContainer.trailingAnchor,
                constant: -6
            ),

            textLabel.topAnchor.constraint(
                equalTo: container.topAnchor,
                constant: 8
            ),
            textLabel.leadingAnchor.constraint(
                equalTo: scoreContainer.trailingAnchor,
                constant: 8
            ),
            textLabel.trailingAnchor.constraint(
                equalTo: container.trailingAnchor,
                constant: -8
            ),
            textLabel.bottomAnchor.constraint(
                equalTo: container.bottomAnchor,
                constant: -8
            ),
        ])

        return container
    }

    @objc private func headerTapped() {
        toggleExpanded()
    }

    func toggleExpanded() {
        isExpanded.toggle()
        updateExpandedState(animated: true)
    }

    private func updateExpandedState(animated: Bool) {
        let imageName = isExpanded ? "chevron.down" : "chevron.right"
        let config = UIImage.SymbolConfiguration(pointSize: 12)
        let image = UIImage(systemName: imageName, withConfiguration: config)

        if animated {
            UIView.animate(withDuration: 0.25) {
                self.chevronImageView.image = image
            }
        } else {
            chevronImageView.image = image
        }

        guard let sourcesContainer = containerStack.arrangedSubviews.last else {
            return
        }

        sourcesContainer.isHidden = !isExpanded

        if isExpanded {
            sourcesContainerHeightConstraint?.isActive = false

            let totalHeight = sourcesStackView.arrangedSubviews.reduce(0) {
                total,
                view in
                let height = view.systemLayoutSizeFitting(
                    CGSize(
                        width: sourcesStackView.bounds.width,
                        height: UIView.layoutFittingCompressedSize.height
                    ),
                    withHorizontalFittingPriority: .required,
                    verticalFittingPriority: .fittingSizeLevel
                ).height
                return total + height + 6  // spacing
            }

            sourcesContainerHeightConstraint = sourcesContainer.heightAnchor
                .constraint(equalToConstant: totalHeight)
            sourcesContainerHeightConstraint?.isActive = true

            if animated {
                UIView.animate(withDuration: 0.25) {
                    self.layoutIfNeeded()
                }
            }
        } else {
            sourcesContainerHeightConstraint?.isActive = false
            sourcesContainerHeightConstraint = sourcesContainer.heightAnchor
                .constraint(equalToConstant: 0)
            sourcesContainerHeightConstraint?.isActive = true

            if animated {
                UIView.animate(withDuration: 0.25) {
                    self.layoutIfNeeded()
                } completion: { _ in
                    sourcesContainer.isHidden = true
                }
            }
        }
    }

    func setSources(_ sources: [RAGSource]) {
        self.sources = sources
        rebuildSourcesStack()
        titleLabel.text = L("chat.sources.title", sources.count)

        if isExpanded {
            updateExpandedState(animated: false)
        }
    }

    func setExpanded(_ expanded: Bool, animated: Bool = true) {
        guard isExpanded != expanded else { return }
        isExpanded = expanded
        updateExpandedState(animated: animated)
    }
}
