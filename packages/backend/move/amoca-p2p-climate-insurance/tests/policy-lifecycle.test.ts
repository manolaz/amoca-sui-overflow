// This is a test file for the policy lifecycle

import {
  calculatePremium,
  createPolicy,
  getPolicyDetails,
  addCollateral,
  removeCollateral,
  terminatePolicy,
  processClaim,
  type PolicyParams,
} from "../services/policy-lifecycle-service"
import { ClimateDataType } from "../services/switchboard-service-updated"

// Mock wallet address
const walletAddress = "0x1a2b3c4d5e6f"

// Test policy parameters
const testPolicyParams: PolicyParams = {
  location: "East Africa",
  locationCoordinates: [-1.2921, 36.8219],
  perilType: ClimateDataType.RAINFALL,
  perilDetails: JSON.stringify({
    description: "Protection against drought (low rainfall)",
    unit: "mm",
  }),
  coverageAmount: 10000,
  triggerThreshold: 25,
  triggerOperator: 0, // Less than
  collateralAmount: 1200,
}

describe("Policy Lifecycle", () => {
  let policyId: string

  test("Calculate premium", async () => {
    const premium = await calculatePremium(testPolicyParams)

    // Verify premium calculation
    expect(premium).toBeDefined()
    expect(premium.basePremium).toBeGreaterThan(0)
    expect(premium.finalPremium).toBeGreaterThan(premium.basePremium)
    expect(premium.fundingRate).toBeGreaterThan(0)
    expect(premium.marginRequirement).toBeGreaterThan(0)

    // Verify adjustments
    expect(premium.locationAdjustment).toBeDefined()
    expect(premium.perilAdjustment).toBeDefined()
    expect(premium.seasonalAdjustment).toBeDefined()
    expect(premium.coverageAdjustment).toBeDefined()
  })

  test("Create policy", async () => {
    policyId = await createPolicy(testPolicyParams, walletAddress)

    // Verify policy creation
    expect(policyId).toBeDefined()
    expect(typeof policyId).toBe("string")
  })

  test("Get policy details", async () => {
    const policyDetails = await getPolicyDetails(policyId)

    // Verify policy details
    expect(policyDetails).toBeDefined()
    expect(policyDetails.id).toBe(policyId)
    expect(policyDetails.owner).toBe(walletAddress)
    expect(policyDetails.location).toBe(testPolicyParams.location)
    expect(policyDetails.perilType).toBe(testPolicyParams.perilType)
    expect(policyDetails.coverageAmount).toBe(testPolicyParams.coverageAmount)
    expect(policyDetails.triggerThreshold).toBe(testPolicyParams.triggerThreshold)
    expect(policyDetails.collateralAmount).toBe(testPolicyParams.collateralAmount)
    expect(policyDetails.active).toBe(true)
  })

  test("Add collateral", async () => {
    const additionalCollateral = 500
    const updatedCollateral = await addCollateral(policyId, additionalCollateral, walletAddress)

    // Verify collateral addition
    expect(updatedCollateral).toBe(testPolicyParams.collateralAmount + additionalCollateral)
  })

  test("Remove collateral", async () => {
    const collateralToRemove = 200
    const updatedCollateral = await removeCollateral(policyId, collateralToRemove, walletAddress)

    // Verify collateral removal
    expect(updatedCollateral).toBe(testPolicyParams.collateralAmount + 500 - collateralToRemove)
  })

  test("Process claim", async () => {
    const claimDetails = await processClaim(policyId, walletAddress)

    // Verify claim processing
    expect(claimDetails).toBeDefined()
    expect(claimDetails.policyId).toBe(policyId)
    expect(claimDetails.owner).toBe(walletAddress)
    expect(claimDetails.triggerValue).toBe(testPolicyParams.triggerThreshold)
    expect(typeof claimDetails.actualValue).toBe("number")

    // Check status and payout
    expect(["Approved", "Rejected", "Pending"]).toContain(claimDetails.status)
    if (claimDetails.status === "Approved") {
      expect(claimDetails.payoutAmount).toBe(testPolicyParams.coverageAmount)
    } else {
      expect(claimDetails.payoutAmount).toBe(0)
    }
  })

  test("Terminate policy", async () => {
    const success = await terminatePolicy(policyId, walletAddress)

    // Verify policy termination
    expect(success).toBe(true)

    // Verify policy is no longer active
    const policyDetails = await getPolicyDetails(policyId)
    expect(policyDetails.active).toBe(false)
  })
})
