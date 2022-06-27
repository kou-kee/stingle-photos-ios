//
//  STCollectionViewDataSource.swift
//  Stingle
//
//  Created by Khoren Asatryan on 4/16/21.
//

import UIKit

//MARK: - Items

protocol IViewDataSourceItemIdentifier: CaseIterable {
    var nibName: String { get }
    var identifier: String { get }
}

protocol IViewDataSourceItemModel {
    associatedtype Identifier: IViewDataSourceItemIdentifier
    var identifier: Identifier { get }
}

protocol IViewDataSourceHeaderModel: IViewDataSourceItemModel {}

protocol IViewDataSourceHeader {
    
    associatedtype Model: IViewDataSourceHeaderModel
    
    func configure(model: Model?)
}

protocol IViewDataSourceCellModel: IViewDataSourceItemModel {}

protocol IViewDataSourceCell {
    
    associatedtype Model: IViewDataSourceCellModel
    
    func configure(model: Model?)
}

//MARK: - ViewModel

protocol ICollectionDataSourceViewModel {

    associatedtype Header: IViewDataSourceHeader, UICollectionReusableView
    associatedtype Cell: IViewDataSourceCell, UICollectionViewCell
    associatedtype Model: ICDSynchConvertable
        
    func cellModel(for indexPath: IndexPath, data: Model?) -> Cell.Model
    func headerModel(for indexPath: IndexPath, section: String) -> Header.Model
    
}

protocol ICollectionDataSourceNoHeaderViewModel: ICollectionDataSourceViewModel where Header == STDataSourceDefaultHeader {}

extension ICollectionDataSourceNoHeaderViewModel {
    
    func headerModel(for indexPath: IndexPath, section: String) -> Header.Model {
        fatalError("NoHeaderViewModel no support headerView")
    }
    
}

class STDataSourceDefaultHeader: UICollectionReusableView, IViewDataSourceHeader {

    enum Identifier: CaseIterable, IViewDataSourceItemIdentifier {
                
        var nibName: String {
            return ""
        }
        
        var identifier: String {
            return ""
        }
        
    }
    
    struct HeaderModel: IViewDataSourceHeaderModel {
        typealias Identifier = STDataSourceDefaultHeader.Identifier
        var identifier: STDataSourceDefaultHeader.Identifier
    }
    
    func configure(model: HeaderModel?) {}
    
}

//MARK: - DataSource

protocol STCollectionViewDataSourceDelegate: AnyObject {
    func dataSource(layoutSection dataSource: IViewDataSource, sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection?
    
    func dataSource(didStartSync dataSource: IViewDataSource)
    func dataSource(didEndSync dataSource: IViewDataSource)
    func dataSource(willApplySnapshot dataSource: IViewDataSource)
    func dataSource(didApplySnapshot dataSource: IViewDataSource)
    
    func dataSource(didConfigureCell dataSource: IViewDataSource, cell: UICollectionViewCell)
    
}

extension STCollectionViewDataSourceDelegate {
    func dataSource(didStartSync dataSource: IViewDataSource) {}
    func dataSource(didEndSync dataSource: IViewDataSource) {}
    func dataSource(didConfigureCell dataSource: IViewDataSource, cell: UICollectionViewCell) {}
}

class STCollectionViewDataSource<ViewModel: ICollectionDataSourceViewModel>: STViewDataSource<ViewModel.Model> {
    
    typealias Model = ViewModel.Model
    typealias Cell = ViewModel.Cell
    typealias Header = ViewModel.Header
    
    private(set) var dataSourceReference: UICollectionViewDiffableDataSourceReference?
    private(set) var isReloadingCollectionView = false
    private(set) weak var collectionView: UICollectionView?
    
    var viewModel: ViewModel
    weak var delegate: STCollectionViewDataSourceDelegate?
    
    init(dbDataSource: STDataBase.DataSource<Model>, collectionView: UICollectionView, viewModel: ViewModel) {
        self.viewModel = viewModel
        self.collectionView = collectionView
        super.init(dbDataSource: dbDataSource)
        self.configure(collectionView: collectionView)
        self.configureLayout(collectionView: collectionView)
        self.createDataSourceReference(collectionView: collectionView)
    }
    
    //MARK: - Override
    
    override func didEndSync(dataSource: IProviderDataSource) {
        if dataSource as? NSObject == self.dbDataSource {
            self.delegate?.dataSource(didEndSync: self)
        }
    }
    
    override func didStartSync(dataSource: IProviderDataSource) {
        if dataSource as? NSObject == self.dbDataSource {
            self.delegate?.dataSource(didStartSync: self)
        }
    }
    
    override func didChangeContent(with snapshot: NSDiffableDataSourceSnapshotReference) {
        self.isReloadingCollectionView = true
        self.delegate?.dataSource(willApplySnapshot: self)
        super.didChangeContent(with: snapshot)
        self.dataSourceReference?.applySnapshot(snapshot, animatingDifferences: true) { [weak self] in
            guard let weakSelf = self else {
                self?.isReloadingCollectionView = false
                return
            }
            weakSelf.delegate?.dataSource(didApplySnapshot: weakSelf)
            weakSelf.isReloadingCollectionView = false
        }
    }
    
    //MARK: - Public
    
    func cellModel(at indexPath: IndexPath) -> Cell.Model? {
        let object = self.object(at: indexPath)
        let cellModel = self.viewModel.cellModel(for: indexPath, data: object)
        return cellModel
    }
    
    func reloadCollection() {
        self.collectionView?.reloadData()
    }
    
    func reloadCollectionVisibleCells() {
        self.collectionView?.indexPathsForVisibleItems.forEach { indexPath in
            if let model = self.cellModel(at: indexPath), let cell = self.collectionView?.cellForItem(at: indexPath) as? Cell {
                cell.configure(model: model)
            }
        }
    }
    
    func reload(indexPaths: [IndexPath], animating: Bool, completion: (() -> Void)? = nil) {
        guard  let snapshot = self.dataSourceReference?.snapshot() else { return }
        
        var identifiers = [Any]()
        indexPaths.forEach { indexPath in
            if let identifier = self.dataSourceReference?.itemIdentifier(for: indexPath) {
                identifiers.append(identifier)
            }
        }
        snapshot.reloadItems(withIdentifiers: identifiers)
        self.dataSourceReference?.applySnapshot(snapshot, animatingDifferences: animating) {
            completion?()
        }
    }
    
    func reload(animating: Bool, completion: (() -> Void)? = nil) {
        guard  let snapshot = self.dataSourceReference?.snapshot() else { return }
        snapshot.reloadItems(withIdentifiers: snapshot.itemIdentifiers)
        self.dataSourceReference?.applySnapshot(snapshot, animatingDifferences: animating) {
            completion?()
        }
    }
    
    func cell(for indexPath: IndexPath) -> Cell? {
        return self.collectionView?.cellForItem(at: indexPath) as? Cell
    }
    
    func cellFor(collectionView: UICollectionView, indexPath: IndexPath, data: Any) -> Cell? {
        guard let cellModel = self.cellModel(at: indexPath) else {
            fatalError("object not found")
        }
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellModel.identifier.identifier, for: indexPath) as! Cell
        cell.configure(model: cellModel)
        self.delegate?.dataSource(didConfigureCell: self, cell: cell)
        return cell
    }
    
    func headerFor(collectionView: UICollectionView, indexPath: IndexPath, kind: String) -> Header? {
        guard let text = self.dbDataSource.sectionTitle(at: indexPath.section) else {
            return nil
        }
        let headerModel = self.viewModel.headerModel(for: indexPath, section: text)
        let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: headerModel.identifier.identifier, for: indexPath) as! Header
        headerView.configure(model: headerModel)
        return headerView
    }
        
    func configure(collectionView: UICollectionView) {
        ViewModel.Cell.Model.Identifier.allCases.forEach { (identifier) in
            collectionView.registrCell(nibName: identifier.nibName, identifier: identifier.identifier)
        }
        ViewModel.Header.Model.Identifier.allCases.forEach { (identifier) in
            collectionView.registerHeader(nibName: identifier.nibName, identifier: identifier.identifier)
        }
    }
    
    @discardableResult
    func configureLayout(collectionView: UICollectionView) -> UICollectionViewCompositionalLayout {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        let layout = UICollectionViewCompositionalLayout(sectionProvider: { [weak self] (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
            return self?.layoutSection(sectionIndex: sectionIndex, layoutEnvironment: layoutEnvironment)
        }, configuration: configuration)
        collectionView.collectionViewLayout = layout
        return layout
    }
    
    func layoutSection(sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? {
        return self.delegate?.dataSource(layoutSection: self, sectionIndex: sectionIndex, layoutEnvironment: layoutEnvironment)
    }
    
    @discardableResult
    func createDataSourceReference(collectionView: UICollectionView) -> UICollectionViewDiffableDataSourceReference {
                
        let dataSourceReference = UICollectionViewDiffableDataSourceReference(collectionView: collectionView, cellProvider: { [weak self] (collectionView, indexPath, data) -> UICollectionViewCell? in
            let cell = self?.cellFor(collectionView: collectionView, indexPath: indexPath, data: data)
            return cell
        })
        dataSourceReference.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            return self?.headerFor(collectionView: collectionView, indexPath: indexPath, kind: kind)
        }
        
        self.dataSourceReference = dataSourceReference
        return dataSourceReference
    }
    
    func generateCollectionLayoutItem() -> NSCollectionLayoutItem {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1))
        let resutl = NSCollectionLayoutItem(layoutSize: itemSize)
        resutl.contentInsets = .zero
        return resutl
    }
        
}
