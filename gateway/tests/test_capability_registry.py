import unittest

from app.capabilities.models import CapabilityPlanRequest
from app.capabilities.registry import CapabilityRegistry, CapabilityRegistryError


class CapabilityRegistryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.registry = CapabilityRegistry()

    def test_catalogue_is_complete_and_unique(self) -> None:
        catalogue = self.registry.catalog
        self.assertEqual(30, len(catalogue.capabilities))
        self.assertEqual(97, len(catalogue.providers))
        self.assertEqual(
            len(catalogue.providers),
            len({provider.id for provider in catalogue.providers}),
        )
        for capability in catalogue.capabilities:
            self.assertTrue(
                any(capability.id in p.capabilities for p in catalogue.providers),
                capability.id,
            )

    def test_absolute_zero_cost_policy_is_machine_enforced(self) -> None:
        policy = self.registry.catalog.policy
        self.assertEqual(0, policy.mandatory_cost_eur)
        self.assertFalse(policy.paid_api_allowed)
        self.assertFalse(policy.payment_card_allowed)
        self.assertFalse(policy.paid_trial_as_dependency)
        self.assertFalse(policy.external_free_tier_critical)
        self.assertFalse(
            any(p.mandatory_paid_api or p.card_required for p in self.registry.catalog.providers)
        )

    def test_commercial_plan_rejects_non_commercial_models(self) -> None:
        plan = self.registry.plan(
            CapabilityPlanRequest(
                capability_id="music.generate",
                available_targets=["server_cpu", "server_gpu"],
                device_tier="L3",
                online=False,
                commercial_use=True,
                allow_gpu=True,
            )
        )
        self.assertIn("ace_step", {item.provider_id for item in plan.eligible})
        rejected = {item.provider_id: item.reasons for item in plan.rejected}
        self.assertIn("audiocraft_musicgen", rejected)
        self.assertIn("license:commercial-use-blocked", rejected["audiocraft_musicgen"])

    def test_no_gpu_request_keeps_a_useful_transcription_path(self) -> None:
        plan = self.registry.plan(
            CapabilityPlanRequest(
                capability_id="audio.transcribe",
                available_targets=["android", "ios", "desktop", "server_cpu"],
                device_tier="L1",
                online=False,
                commercial_use=True,
                allow_gpu=False,
            )
        )
        self.assertIn("whisper_cpp", {item.provider_id for item in plan.eligible})

    def test_conditional_licences_require_explicit_opt_in(self) -> None:
        request = CapabilityPlanRequest(
            capability_id="document.parse",
            available_targets=["server_cpu"],
            device_tier="L2",
            online=False,
            commercial_use=True,
            allow_conditional_licenses=False,
            allow_gpu=False,
        )
        plan = self.registry.plan(request)
        rejected = {item.provider_id: item.reasons for item in plan.rejected}
        self.assertIn("docling", rejected)
        self.assertIn("license:review-required", rejected["docling"])

    def test_unknown_capability_is_rejected(self) -> None:
        with self.assertRaises(CapabilityRegistryError):
            self.registry.plan(
                CapabilityPlanRequest(
                    capability_id="unknown.capability",
                    available_targets=["server_cpu"],
                )
            )


if __name__ == "__main__":
    unittest.main()
