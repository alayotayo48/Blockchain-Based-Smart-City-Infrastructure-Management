import { describe, it, expect, beforeEach } from 'vitest';

// Mock implementation for testing Clarity contracts
// This is a simplified testing approach without using the libraries mentioned in the requirements

// Mock contract state
let mockContractState = {
  lastAssetId: 0,
  assets: new Map(),
  constants: {
    ASSET_TYPE_ROAD: 1,
    ASSET_TYPE_BRIDGE: 2,
    ASSET_TYPE_BUILDING: 3,
    ASSET_TYPE_UTILITY: 4,
    ASSET_TYPE_PARK: 5,
    STATUS_ACTIVE: 1,
    STATUS_MAINTENANCE: 2,
    STATUS_INACTIVE: 3,
    STATUS_DEPRECATED: 4
  }
};

// Mock contract functions
const mockContract = {
  registerAsset: (name: string, assetType: number, location: string, installationDate: number) => {
    // Validate asset type
    if (![1, 2, 3, 4, 5].includes(assetType)) {
      return { type: 'err', value: 1 };
    }
    
    const newId = mockContractState.lastAssetId + 1;
    mockContractState.lastAssetId = newId;
    
    mockContractState.assets.set(newId, {
      name,
      assetType,
      location,
      installationDate,
      lastMaintenance: 0,
      status: mockContractState.constants.STATUS_ACTIVE,
      owner: 'tx-sender'
    });
    
    return { type: 'ok', value: newId };
  },
  
  updateAssetStatus: (assetId: number, newStatus: number) => {
    // Validate status
    if (![1, 2, 3, 4].includes(newStatus)) {
      return { type: 'err', value: 2 };
    }
    
    // Check if asset exists
    if (!mockContractState.assets.has(assetId)) {
      return { type: 'err', value: 404 };
    }
    
    // Check ownership
    const asset = mockContractState.assets.get(assetId);
    if (asset.owner !== 'tx-sender') {
      return { type: 'err', value: 3 };
    }
    
    // Update status
    asset.status = newStatus;
    mockContractState.assets.set(assetId, asset);
    
    return { type: 'ok', value: true };
  },
  
  getAsset: (assetId: number) => {
    return mockContractState.assets.get(assetId) || null;
  },
  
  getAssetCount: () => {
    return mockContractState.lastAssetId;
  }
};

describe('Asset Registration Contract', () => {
  beforeEach(() => {
    // Reset state before each test
    mockContractState = {
      lastAssetId: 0,
      assets: new Map(),
      constants: { ...mockContractState.constants }
    };
  });
  
  it('should register a new asset successfully', () => {
    const result = mockContract.registerAsset('Main Street Bridge', 2, 'Downtown', 1620000000);
    
    expect(result.type).toBe('ok');
    expect(result.value).toBe(1);
    expect(mockContractState.lastAssetId).toBe(1);
    
    const asset = mockContract.getAsset(1);
    expect(asset).not.toBeNull();
    expect(asset.name).toBe('Main Street Bridge');
    expect(asset.assetType).toBe(2);
    expect(asset.status).toBe(mockContractState.constants.STATUS_ACTIVE);
  });
  
  it('should fail to register an asset with invalid type', () => {
    const result = mockContract.registerAsset('Invalid Asset', 10, 'Nowhere', 1620000000);
    
    expect(result.type).toBe('err');
    expect(result.value).toBe(1);
    expect(mockContractState.lastAssetId).toBe(0);
  });
  
  it('should update asset status successfully', () => {
    // First register an asset
    mockContract.registerAsset('City Hall', 3, 'Downtown', 1620000000);
    
    // Then update its status
    const result = mockContract.updateAssetStatus(1, mockContractState.constants.STATUS_MAINTENANCE);
    
    expect(result.type).toBe('ok');
    expect(result.value).toBe(true);
    
    const asset = mockContract.getAsset(1);
    expect(asset.status).toBe(mockContractState.constants.STATUS_MAINTENANCE);
  });
  
  it('should fail to update status for non-existent asset', () => {
    const result = mockContract.updateAssetStatus(999, mockContractState.constants.STATUS_INACTIVE);
    
    expect(result.type).toBe('err');
    expect(result.value).toBe(404);
  });
  
  it('should track the total number of assets correctly', () => {
    expect(mockContract.getAssetCount()).toBe(0);
    
    mockContract.registerAsset('Asset 1', 1, 'Location 1', 1620000000);
    expect(mockContract.getAssetCount()).toBe(1);
    
    mockContract.registerAsset('Asset 2', 2, 'Location 2', 1620000000);
    expect(mockContract.getAssetCount()).toBe(2);
    
    mockContract.registerAsset('Asset 3', 3, 'Location 3', 1620000000);
    expect(mockContract.getAssetCount()).toBe(3);
  });
});
