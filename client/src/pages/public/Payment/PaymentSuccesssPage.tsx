import { useEffect, useState } from "react";
import { useSearchParams, useNavigate } from "react-router-dom";
import { CheckCircle, Home, Loader2 } from "lucide-react";
import { motion, type Variants } from "framer-motion";
import { verifyPaymentSession } from "@/apis/payment.api";

function PaymentSuccessPage() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const sessionId = searchParams.get("session_id");

  const [isVerifying, setIsVerifying] = useState(!!sessionId);
  const [verifyError, setVerifyError] = useState<string | null>(null);

  useEffect(() => {
    window.scrollTo(0, 0);
  }, []);

  // Verify the session so the meeting is guaranteed to exist before the user
  // navigates to the dashboard. The webhook may not have fired yet.
  useEffect(() => {
    if (!sessionId) return;

    const verify = async () => {
      try {
        const result = await verifyPaymentSession(sessionId);
        if (!result.success) {
          setVerifyError(result.message);
        }
      } catch {
        setVerifyError("Could not confirm your booking. Please contact support.");
      } finally {
        setIsVerifying(false);
      }
    };

    void verify();
  }, [sessionId]);

  const containerVariants: Variants = {
    hidden: { opacity: 0, scale: 0.95 },
    visible: {
      opacity: 1,
      scale: 1,
      transition: {
        duration: 0.5,
        ease: "easeOut" as const,
        staggerChildren: 0.15,
      },
    },
  };

  const itemVariants: Variants = {
    hidden: { opacity: 0, y: 20 },
    visible: { opacity: 1, y: 0, transition: { duration: 0.5 } },
  };

  const iconVariants: Variants = {
    hidden: { scale: 0, rotate: -180 },
    visible: {
      scale: 1,
      rotate: 0,
      transition: {
        type: "spring" as const,
        stiffness: 260,
        damping: 20,
      },
    },
  };

  // Show loading while verifying the session with the server
  if (isVerifying) {
    return (
      <div className='flex min-h-screen w-full items-center justify-center bg-(--secondary)'>
        <div className='flex flex-col items-center gap-4 text-white'>
          <Loader2 className='h-12 w-12 animate-spin text-(--primary)' />
          <p className='text-lg font-medium'>Confirming your booking...</p>
        </div>
      </div>
    );
  }

  return (
    <div className='flex min-h-screen w-full items-center justify-center bg-(--secondary) py-15'>
      <div className='w-11/12 max-w-lg'>
        <motion.div
          variants={containerVariants}
          initial='hidden'
          animate='visible'
          className='flex flex-col items-center rounded-xl border bg-gray-800 px-7 py-10 shadow-2xl'
        >
          {/* Icon */}
          <motion.div variants={iconVariants}>
            <div className='mb-6 flex h-24 w-24 items-center justify-center rounded-full bg-(--green)/10 ring-2 ring-(--green)'>
              <CheckCircle className='h-12 w-12 text-(--green)' />
            </div>
          </motion.div>

          {/* Heading */}
          <motion.h2 variants={itemVariants} className='mb-2 text-center text-3xl font-bold text-white'>
            Payment Successful!
          </motion.h2>

          <motion.p variants={itemVariants} className='mb-8 text-center text-gray-300'>
            {verifyError ??
              "Thank you for your booking. Your mentorship session has been confirmed and added to your schedule."}
          </motion.p>

          {/* Transaction Info */}
          {sessionId && !verifyError && (
            <motion.div
              variants={itemVariants}
              className='mb-8 w-full rounded-lg border border-gray-700 bg-gray-900/50 p-4'
            >
              <div className='flex flex-col items-center gap-1'>
                <span className='text-xs tracking-wider text-gray-500 uppercase'>Transaction ID</span>
                <span className='font-mono text-sm break-all text-gray-300'>{sessionId}</span>
              </div>
            </motion.div>
          )}

          {/* Action Buttons */}
          <motion.div variants={itemVariants} className='flex w-full flex-col gap-4'>
            <motion.button
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
              onClick={() => void navigate("/mentee/dashboard")}
              className='flex w-full items-center justify-center gap-2 rounded-lg bg-(--primary) py-3 font-bold text-white shadow-lg shadow-purple-900/20 transition hover:bg-purple-700'
            >
              <Home className='h-5 w-5' />
              Back to Dashboard
            </motion.button>
          </motion.div>

          <motion.div variants={itemVariants} className='mt-8 text-sm text-gray-500'>
            Need help? <span className='cursor-pointer text-(--primary) hover:underline'>Contact Support</span>
          </motion.div>
        </motion.div>
      </div>
    </div>
  );
}

export default PaymentSuccessPage;
