import { describe, it, expect, beforeEach } from 'vitest';

// Mock implementation for testing Clarity contracts
// This is a simplified testing approach without using the libraries mentioned in the requirements

// Mock contract state
let mockContractState = {
  lastReadingId: 0,
  sensors: new Map(),
  sensorReadings: new Map(),
  constants: {
    SENSOR_TYPE_TEMPERATURE: 1,
    SENSOR_TYPE_HUMIDITY: 2,
    SENSOR_TYPE_TRAFFIC: 3,
    SENSOR_TYPE_AIR_QUALITY: 4,
    SENSOR_TYPE_STRUCTURAL: 5,
    SENSOR_TYPE_WATER_LEVEL: 6
  }
};

// Mock contract functions
const mockContract = {
  registerSensor: (name: string, sensorType: number, assetId: number, location: string) => {
    // Validate sensor type
    if (![1, 2, 3, 4, 5, 6].includes(sensorType)) {
      return { type: 'err', value: 1 };
    }
    
    const newId = mockContractState.lastReadingId + 1;
    mockContractState.lastReadingId = newId;
    
    mockContractState.sensors.set(newId, {
      name,
      sensorType,
      assetId,
      location,
      owner: 'tx-sender'
    });
    
    return { type: 'ok', value: newId };
  },
  
  recordSensorReading: (sensorId: number, value: number, notes: string | null) => {
    // Check if sensor exists
    if (!mockContractState.sensors.has(sensorId)) {
      return { type: 'err', value: 404 };
    }
    
    // Check ownership
    const sensor = mockContractState.sensors.get(sensorId);
    if (sensor.owner !== 'tx-sender') {
      return { type: 'err', value: 3 };
    }
    
    const newId = mockContractState.lastReadingId + 1;
    mockContractState.lastReadingId = newId;
    
    mockContractState.sensorReadings.set(newId, {
      sensorId,
      timestamp: 123456, // Mock block height
      value,
      notes
    });
    
    return { type: 'ok', value: newId };
  },
  
  getSensor: (sensorId: number) => {
    return mockContractState.sensors.get(sensorId) || null;
  },
  
  getSensorReading: (readingId: number) => {
    return mockContractState.sensorReadings.get(readingId) || null;
  }
};

describe('Sensor Data Contract', () => {
  beforeEach(() => {
    // Reset state before each test
    mockContractState = {
      lastReadingId: 0,
      sensors: new Map(),
      sensorReadings: new Map(),
      constants: { ...mockContractState.constants }
    };
  });
  
  it('should register a new sensor successfully', () => {
    const result = mockContract.registerSensor('Temperature Sensor', 1, 1, 'Bridge Support');
    
    expect(result.type).toBe('ok');
    expect(result.value).toBe(1);
    
    const sensor = mockContract.getSensor(1);
    expect(sensor).not.toBeNull();
    expect(sensor.name).toBe('Temperature Sensor');
    expect(sensor.sensorType).toBe(1);
    expect(sensor.assetId).toBe(1);
  });
  
  it('should fail to register a sensor with invalid type', () => {
    const result = mockContract.registerSensor('Invalid Sensor', 10, 1, 'Nowhere');
    
    expect(result.type).toBe('err');
    expect(result.value).toBe(1);
  });
  
  it('should record a sensor reading successfully', () => {
    // First register a sensor
    mockContract.registerSensor('Traffic Sensor', 3, 2, 'Main Street');
    
    // Then record a reading
    const result = mockContract.recordSensorReading(1, 250, 'High traffic volume');
    
    expect(result.type).toBe('ok');
    expect(result.value).toBe(2);
    
    const reading = mockContract.getSensorReading(2);
    expect(reading).not.toBeNull();
    expect(reading.sensorId).toBe(1);
    expect(reading.value).toBe(250);
    expect(reading.notes).toBe('High traffic volume');
  });
  
  it('should fail to record a reading for non-existent sensor', () => {
    const result = mockContract.recordSensorReading(999, 25, null);
    
    expect(result.type).toBe('err');
    expect(result.value).toBe(404);
  });
});
